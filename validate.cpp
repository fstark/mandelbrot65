#include <array>
#include <cstdint>
#include <cstdio>
#include <iostream>
#include <ostream>
#include <cassert>
#include <cstring>
#include <sstream>
#include <fstream>
#include <algorithm>

const int ISIZE=3;
const int ISIZE_MAX=(1 << ISIZE) - 1;
const int FSIZE=8;
const int FSIZE_MAX=(1 << FSIZE) - 1;

class fixed_t;
std::ostream& operator<<(std::ostream& os, const fixed_t& f);


// A 11 bits fixed point class (3+8)
class fixed_t
{
	bool sign_ : 1;
    unsigned int integer_ : ISIZE;
    unsigned int fractional_ : FSIZE;

public:
	fixed_t() : sign_(false), integer_(0), fractional_(0) {}

	fixed_t(bool sign, int integer, int fractional) : sign_(sign), integer_(integer), fractional_(fractional)
	{
		// printf( "sign: %d, integer: %d, fractional: %d\n", sign, integer, fractional );
		assert( integer >= 0 && integer <= ISIZE_MAX );
		assert( fractional >= 0 && fractional <= FSIZE_MAX );
	}

	fixed_t(int integer, int fractional) : fixed_t(integer < 0, std::abs(integer), fractional) {}

	fixed_t(float v)
	{
// printf( "%f=>", v );	
		bool sign = v<0;
		int integer = static_cast<int>(std::abs(v));
		int fractional = static_cast<int>((std::abs(v) - static_cast<int>(std::abs(v))) * (FSIZE_MAX+1.0) + 0.5);
// printf( " [%d] ", fractional);
		if (fractional > FSIZE_MAX)
		{
			integer++;
			fractional = 0;
		}
		if (integer>ISIZE_MAX)
		{
			*this = max_fixed();
			return;
		}
		*this = fixed_t(sign, integer, fractional);
// printf( "%s\n", to_string().c_str() );
	}

	static fixed_t max_fixed() { return fixed_t(ISIZE_MAX, FSIZE_MAX); }
	static fixed_t min_fixed() { return fixed_t(-ISIZE_MAX, FSIZE_MAX); }
	static fixed_t epsilon( int count=1 ) { return fixed_t(0, count); }

    std::array<uint8_t, 2> get() const
    {
        return {static_cast<uint8_t>(integer_), static_cast<uint8_t>(fractional_)};
    }

	std::string to_string() const
	{
		if (integer_ == ISIZE_MAX && fractional_ == FSIZE_MAX)
		{
			return "<MAX>";
		}
		// return (sign_ ? "-" : "") + std::to_string(integer_ + fractional_ / (FSIZE_MAX+1.0))+"("+std::to_string(integer_)+":"+std::to_string(fractional_)+")";
		return std::to_string(to_float())+"("+std::to_string(integer_)+":"+std::to_string(fractional_)+")";
	}

	float to_float() const
	{
		return (sign_ ? -1 : 1) * (integer_ + fractional_ / (FSIZE_MAX+1.0));
	}

	fixed_t set_sign(bool sign) const
	{
		return fixed_t(sign, integer_, fractional_);
	}

	bool is_max() const
	{
		return integer_ == ISIZE_MAX && fractional_ == FSIZE_MAX;
	}	

	fixed_t times_positive( fixed_t other) const
	{
		if (is_max() || other.is_max())
		{
			return max_fixed();
		}
		return to_float()*other.to_float();
	}

	fixed_t times(const fixed_t& other) const
	{
		bool sign = sign_ ^ other.sign_;
		return times_positive(other).set_sign(sign);
	}

	bool compare_positive( const fixed_t& other) const
	{
		if (integer_ != other.integer_)
		{
			return integer_ < other.integer_;
		}
		return fractional_ < other.fractional_;
	}

	bool operator<(const fixed_t& other) const
	{
		if (sign_ != other.sign_)
		{
			return sign_ ? -1 : +1;
		}

		return this->abs().compare_positive(other.abs());
	}

	bool operator==(const fixed_t& other) const
	{
		return sign_ == other.sign_ && integer_ == other.integer_ && fractional_ == other.fractional_;
	}

	bool operator!=(const fixed_t& other) const
	{
		return !(*this == other);
	}

	fixed_t operator-() const
	{
		return fixed_t(!sign_, integer_, fractional_);
	}

	fixed_t abs() const
	{
		return fixed_t(false, integer_, fractional_);
	}

	// Adds two positive numbers
	fixed_t add_positive( const fixed_t& other ) const
	{
		assert( sign_ == false );
		assert( other.sign_ == false );

		int integer = integer_ + other.integer_;
		int fractional = fractional_ + other.fractional_;
		if (fractional > FSIZE_MAX)
		{
			integer++;
			fractional -= FSIZE_MAX+1;
		}
		if (integer > ISIZE_MAX)
		{
			return max_fixed();
		}
		return fixed_t(integer, fractional);
	}

	//	Subs a positive number froma larger one
	fixed_t sub_positive( const fixed_t& other ) const
	{
		assert( sign_ == false );
		assert( other.sign_ == false );

		int integer = integer_ - other.integer_;
		int fractional = fractional_ - other.fractional_;
		if (fractional < 0)
		{
			integer--;
			fractional += FSIZE_MAX+1;
		}
		if (integer < 0)
		{
			return min_fixed();
		}
		return fixed_t(integer, fractional);
	}

	fixed_t operator+(const fixed_t& other) const
	{
		// std::cout << "ADD " << *this << " + " << other << std::endl;

		//	Same sign addition
		if (sign_ == other.sign_)
		{
			return abs().add_positive(other.abs()).set_sign(sign_);
		}

		//	Different sign (substraction)
		auto xa = this->abs();
		auto ya = other.abs();
		fixed_t result;

		//	Other wins
		if (xa < ya)
		{
			return ya.sub_positive(xa).set_sign(other.sign_);
		}

		return xa.sub_positive(ya).set_sign(sign_);
	}

	fixed_t operator-(const fixed_t& other) const
	{
		return *this + (-other);
	}

	fixed_t squared() const
	{
		return times(*this);
	}

	fixed_t div2() const
	{
		int integer = integer_;
		int fractional = fractional_;

		fractional >>= 1;
		if (integer & 1)
		{
			fractional |= 1 << (FSIZE-1);
		}

		integer >>= 1;

		return fixed_t(sign_, integer, fractional);
	}

	bool is_even_epsilon()
	{
		return (fractional_ & 1) == 0;
	}

	//	Multiplies two numbers using only squares and add/subtract
	//	Returns the double of the multiplication
	fixed_t mul2(const fixed_t& other) const
	{
		// Multiplication using only squares and add/subtract
		// (x-y)^2 = x^2 - 2xy + y^2
		// 2xy = x^2 + y^2 - (x-y)^2
		// xy = (x^2 + y^2 - (x-y)^2) / 2

		fixed_t x = *this;
		fixed_t y = other;
		auto x2 = x.squared();
		if (x2.is_max())
		{
			return max_fixed();
		}
		auto y2 = y.squared();
		if (y2.is_max())
		{
			return max_fixed();
		}
		auto xmy2 = (x - y).squared();
		if (x<y)
			return y2-xmy2+x2;
		return x2-xmy2+y2;
	}
};

std::ostream& operator<<(std::ostream& os, const fixed_t& f)
{
	os << f.to_string();
	return os;
}

void test_creation()
{
	//	Positive numbers
	assert( fixed_t(1, 0) == fixed_t(1.0) );
	assert( fixed_t(1, (FSIZE_MAX + 1) / 8) == fixed_t(1.125) );
	assert( fixed_t(1, (FSIZE_MAX + 1) / 4) == fixed_t(1.25) );
	assert( fixed_t(1, (FSIZE_MAX + 1) / 8 * 3) == fixed_t(1.375) );
	assert( fixed_t(1, (FSIZE_MAX + 1) / 2) == fixed_t(1.5) );
	assert( fixed_t(1, (FSIZE_MAX + 1) / 8 * 5) == fixed_t(1.625) );
	assert( fixed_t(1, (FSIZE_MAX + 1) / 8 * 6) == fixed_t(1.75) );
	assert( fixed_t(1, (FSIZE_MAX + 1) / 8 * 7) == fixed_t(1.875) );
	assert( fixed_t(2, 0) == fixed_t(2.0) );
	assert( fixed_t(0, (FSIZE_MAX + 1) / 8) == fixed_t(0.125) );

	//	Negative numbers
	assert( fixed_t(-1, 0) == fixed_t(-1.0) );
	assert( fixed_t(-1, (FSIZE_MAX + 1) / 8) == fixed_t(-1.125) );
	assert( fixed_t(-1, (FSIZE_MAX + 1) / 4) == fixed_t(-1.25) );
	assert( fixed_t(-1, (FSIZE_MAX + 1) / 8 * 3) == fixed_t(-1.375) );
	assert( fixed_t(-1, (FSIZE_MAX + 1) / 2) == fixed_t(-1.5) );
	assert( fixed_t(-1, (FSIZE_MAX + 1) / 8 * 5) == fixed_t(-1.625) );
	assert( fixed_t(-1, (FSIZE_MAX + 1) / 8 * 6) == fixed_t(-1.75) );
	assert( fixed_t(-1, (FSIZE_MAX + 1) / 8 * 7) == fixed_t(-1.875) );
	assert( fixed_t(-2, 0) == fixed_t(-2.0) );
	assert( fixed_t(-2, (FSIZE_MAX + 1) / 2) == fixed_t(-2.5) );

	//	Epsilons
	assert(fixed_t::epsilon() == fixed_t(0, 1));
	assert(fixed_t::epsilon(2) == fixed_t(0, 2));
	assert(fixed_t::epsilon(3) == fixed_t(0, 3));
	assert(fixed_t::epsilon(4) == fixed_t(0, 4));
	assert(fixed_t::epsilon(5) == fixed_t(0, 5));
}

void test_times()
{
	// test times_positive
	assert( fixed_t(1, 0).times_positive(fixed_t(1, 0)) == fixed_t(1, 0) );
	assert( fixed_t(1, 0).times_positive(fixed_t(1, 1)) == fixed_t(1, 1) );
	assert( fixed_t(1, 0).times_positive(fixed_t(1, 2)) == fixed_t(1, 2) );

	//	Test floats
	assert( fixed_t(1.5).times(fixed_t(1.5)) == fixed_t(2.25) );
	assert( fixed_t(1.5).times(fixed_t(1.25)) == fixed_t(1.875) );
	assert( fixed_t(1.5).times(fixed_t(1.75)) == fixed_t(2.625) );
	assert( fixed_t(1.5).times(fixed_t(1.0)) == fixed_t(1.5) );
	assert( fixed_t(1.5).times(fixed_t(2.0)) == fixed_t(3.0) );
	assert( fixed_t(1.5).times(fixed_t(0.5)) == fixed_t(0.75) );

	//	Multiply per zero
	assert( fixed_t(1.5).times(fixed_t(0.0)) == fixed_t(0.0) );

	//	Mutiply per epsilon
	assert( fixed_t(1.0).times(fixed_t::epsilon()) == fixed_t::epsilon() );
	assert( fixed_t(1.0).times(fixed_t::epsilon(2)) == fixed_t::epsilon(2) );
	assert( fixed_t(2.0).times(fixed_t::epsilon()) == fixed_t::epsilon(2) );
	assert( fixed_t(2.0).times(fixed_t::epsilon(2)) == fixed_t::epsilon(4) );
	assert( fixed_t::epsilon(1).times(fixed_t::epsilon(1)) == fixed_t(0) );

	//	Test saturation (max)
	assert( fixed_t::max_fixed().times(fixed_t(1, 0)) == fixed_t::max_fixed() );
	assert( fixed_t::max_fixed().times(fixed_t(0, 1)) == fixed_t::max_fixed() );
}

void test_plus()
{
	// Tests operator+
	assert( fixed_t(1) + fixed_t(1) == fixed_t(2) );
	assert( fixed_t(1) + fixed_t(2) == fixed_t(3) );
	assert( fixed_t(1) + fixed_t(3) == fixed_t(4) );
	assert( fixed_t(1) + fixed_t(4) == fixed_t(5) );
	assert((fixed_t(1.5) + fixed_t(2.5)) == fixed_t(4.0));
	assert((fixed_t(-1) + fixed_t(2)) == fixed_t(1));
	assert((fixed_t(-3) + fixed_t(-2)) == fixed_t(-5));
	assert((fixed_t(-3) + fixed_t(2)) == fixed_t(-1));
	assert((fixed_t(-1.5) + fixed_t(2.5)) == fixed_t(1.0));
	assert((fixed_t(0) + fixed_t(2)) == fixed_t(2));

	// Test commutativity of addition
	assert((fixed_t(1) + fixed_t(2)) == (fixed_t(2) + fixed_t(1)));
	assert((fixed_t(1.5) + fixed_t(2.5)) == (fixed_t(2.5) + fixed_t(1.5)));
	assert((fixed_t(-1) + fixed_t(2)) == (fixed_t(2) + fixed_t(-1)));
	assert((fixed_t(-1.5) + fixed_t(2.5)) == (fixed_t(2.5) + fixed_t(-1.5)));
	assert((fixed_t(0) + fixed_t(2)) == (fixed_t(2) + fixed_t(0)));

	//	Test saturation (max)
	assert( fixed_t::max_fixed() + fixed_t(1) == fixed_t::max_fixed() );
	assert( fixed_t::max_fixed() + fixed_t::max_fixed() == fixed_t::max_fixed() );
	assert( fixed_t::max_fixed() + fixed_t::epsilon() == fixed_t::max_fixed() );

	//	Test we get to saturation
	assert( fixed_t(ISIZE_MAX) + fixed_t::epsilon() == fixed_t(ISIZE_MAX,1) );
	assert( fixed_t(ISIZE_MAX) + fixed_t(1) == fixed_t::max_fixed() );

	//	Iterate from 0 to max by eplison steps
	fixed_t f(0);
	while (f < fixed_t::max_fixed())
	{
		f = f + fixed_t::epsilon();
	}
}

void check_mul2( fixed_t a, fixed_t b )
{
	auto result = a.mul2(b);
	fixed_t expected(a.to_float() * b.to_float() * 2);

	if (fixed_t(2,211)<a || fixed_t(2,211)<b)
	{
		expected = fixed_t::max_fixed();
	}

	if (fixed_t::epsilon(1)<(result-expected).abs())
	{
		std::cout << a << " * " << b << " = " << result << " != " << expected << std::endl;
		std::cout << "    " << a.squared() << "+" << b.squared() << "-" << (a-b).squared() << " (" << a-b << ")" << std::endl;
	}
}

void test_mul()
{
	//	Test mul2
	assert( fixed_t(1).mul2(fixed_t(1)) == fixed_t(2) );
	assert( fixed_t(1).mul2(fixed_t(2)) == fixed_t(4) );
	assert( fixed_t(1).mul2(fixed_t(3)) == fixed_t::max_fixed() );
	assert( fixed_t(2).mul2(fixed_t(2)) == fixed_t::max_fixed() );
	assert( fixed_t(2).mul2(fixed_t(0.5)) == fixed_t(2) );
	assert( fixed_t(2).mul2(fixed_t::epsilon()) == fixed_t(0, 4) );
	assert( fixed_t(-2).mul2(fixed_t(0.5)) == fixed_t(-2) );
	assert( fixed_t(2).mul2(fixed_t(-0.5)) == fixed_t(-2) );
	assert( fixed_t(-2).mul2(fixed_t(-0.5)) == fixed_t(2) );

// std::cout << fixed_t(0,1).squared() << std::endl;
// std::cout << fixed_t(0,20).squared() << std::endl;
// std::cout << fixed_t(0,1)-fixed_t(0,20) << std::endl;
// std::cout << (fixed_t(0,1)-fixed_t(0,20)).squared() << std::endl;

// 	assert( fixed_t(0,1) * fixed_t(0,20) == fixed_t(0) );

	//	Iterate over all positive multiplication cases
	fixed_t f(0);
	while (f < fixed_t::max_fixed())
	{
		fixed_t g(0);
		while (g < fixed_t::max_fixed())
		{
			check_mul2(f, g);
			g = g + fixed_t::epsilon();
		}
		f = f + fixed_t::epsilon();
	}
}

// Tests for the fixed point class
void test_fixed()
{
	test_creation();
	test_times();
	test_plus();
	test_mul();
}

class ioutput
{
protected:
	int w_;
	int h_;
public:
	virtual ~ioutput() {}
	void output_start( const std::string s, int w, int h )
	{
		w_ = w;
		h_ = h;
		do_output_start( s );
	}
	virtual void do_output_start( const std::string s ) {}

	void output( char c, fixed_t fx, fixed_t fy )
	{
		do_output( c, fx, fy );
	};
	
	virtual void do_output( char c, fixed_t fx, fixed_t fy ) = 0;

	void output_end()
	{
		do_output_end();
	}

	virtual void do_output_end() {}
};

class asm_output : public ioutput
{
	int screen_x = 0;

public:
	virtual void do_output_start( const std::string s )
	{
		// Replace ':' by '/' in s
		std::string modified_s = s; // Create a copy of the string
		std::replace(modified_s.begin(), modified_s.end(), ':', '/'); // Replace ':' with '/'

		std::cout << "; " << modified_s;
		std::cout << std::endl;
	}

	virtual void do_output( char c, fixed_t fx, fixed_t fy )
	{
		if (screen_x==0)
			std::cout << "  .byte \"";

		if (c==':')
			std::cout << "\\";
		std::cout << c;
		screen_x++;
		if (screen_x==w_)
		{
			std::cout << "\"";
			std::cout << std::endl;
			screen_x = 0;
		}
	}

	virtual void do_output_end()
	{
		std::cout << "  .byte 0";
		std::cout << std::endl;
	}
};

class font_t
{
	static const int width = 8;
	static const int height = 8;
	static const int size = 64;

	uint8_t font_[size*height];
public:
	font_t( const char *name )
	{
		// Load file into font_
		FILE *f = fopen(name, "rb");
		if (f==nullptr)
		{
			std::cerr << "Cannot open file " << name << std::endl;
			exit(1);
		}
		if (fread(font_, size*height, 1, f)!=1)
		{
			std::cerr << "Cannot read file " << name << std::endl;
			exit(1);
		}
		fclose(f);
	}

	const uint8_t *get( int c ) const
	{
		c %= size;
		return font_+c*height;
	}
};

class img_output : public ioutput
{
	const font_t &font_;

	uint8_t *data;
	// [40*24*8];

	int x_ = 0;
	int y_ = 0;

	int index_ = 0;
public:
	img_output( const font_t &font ) : font_(font) {}

	virtual void do_output_start( const std::string s )
	{
		x_ = y_ = 0;
		data = new uint8_t[w_*h_*8];
	}

	virtual void do_output( char c, fixed_t fx, fixed_t fy )
	{
		int offset = y_*w_*8+x_;

		if ((y_%24)==0)
		{
			std::string s = std::to_string( fx.to_float() )+","+std::to_string( fy.to_float() );
			int x = x_%40;
			if (x<s.size())
				c = s[x];
		}

		auto p = font_.get(c);
		for (int i=0;i!=8;i++)
		{
			assert( offset+i*w_ >= 0 );
			assert( offset+i*w_ < w_*h_*8 );
			data[offset+i*w_] = p[i];
		}

		x_++;
		if (x_==w_)
		{
			x_ = 0;
			y_++;
		}
	}

	virtual void do_output_end()
	{
		std::string filename = "/tmp/mandel";
		filename += std::to_string(index_++);
		filename += ".pbm";
		// Write data as a 320x192 black and white pixel image
		std::ofstream ofs(filename, std::ios::binary);
		if (!ofs) {
			std::cerr << "Cannot open file " << filename << std::endl;
			return;
		}
		ofs << "P4" << std::endl;
		ofs << w_*8 << " " << h_*8 << std::endl;
		for (int i = 0; i < h_*8; i++)
		{
			for (int j = 0; j < w_; j++)
			{
				auto v = (uint8_t)((data[i * w_ + j]^0xff));
				if ((i%(24*8))==0)
					v ^= 0xff;
				if ((j%40)==0)
					v ^= 0x80;
				ofs << v;
			}
		}
		ofs.close();
	}
};

struct place_t
{
	fixed_t x_;
	fixed_t y_;
	fixed_t rx_;
	fixed_t ry_;

	int w_ = 40;
	int h_ = 24;

	place_t(fixed_t x, fixed_t y, int rx, int ry, int w=40, int h=24) : x_(x), y_(y), rx_(fixed_t::epsilon(rx)), ry_(fixed_t::epsilon(ry)), w_(w), h_(h)
	{
		x_ = x_.to_float()-rx_.to_float()*w_/2;
		y_ = y_.to_float()-ry_.to_float()*h_/2;
	}

	std::string description() const
	{
		std::stringstream ss;
		ss << "x= " << x_ << " y= " << y_ << " rx= " << rx_ << " ry= " << ry_;
		return ss.str();
	}
};

int iter( fixed_t x, fixed_t y, fixed_t zx, fixed_t zy )
{
	fixed_t zx2 = zx.squared();
	fixed_t zy2 = zy.squared();
	int i = 0;
	while (i < 250 && (zx2 + zy2) != fixed_t::max_fixed())
	{
		zy = zx.mul2(zy) + y;
		zx = zx2 - zy2 + x;
		zx2 = zx.squared();
		zy2 = zy.squared();
		i++;
	}
	return i;
}

char palette( int i )
{
	i /= 2;
	const char *p = " .,'~=+:;[/<*?&o0x#";
	if (i<3)
		return ' ';
	i -= 3;
	if (i>=strlen(p))
		return '#';
	return p[i];
}

void mandel( const place_t &place, ioutput &out )
{
	out.output_start( place.description(), place.w_, place.h_ );
	auto y = place.y_;
	for (int i=0;i!=place.h_;i++)
	{
		auto x = place.x_;
		for (int j=0;j!=place.w_;j++)
		{
			int it = iter(x,y,x,y);
			out.output( palette(it), x, y );
			x = x + place.rx_;
		}
		y = y + place.ry_;
		std::cout << i << " " << std::flush;
	}
	out.output_end();
	std::cout << std::endl;
}

void julia( const place_t &place, fixed_t cx, fixed_t cy, ioutput &out )
{
	out.output_start( place.description(), place.w_, place.h_ );
	auto y = place.y_;
	for (int i=0;i!=place.h_;i++)
	{
		auto x = place.x_;
		for (int j=0;j!=place.w_;j++)
		{
			int it = iter(cx,cy,x,y);
			out.output( palette(it), x, y );
			x = x + place.rx_;
		}
		y = y + place.ry_;
		std::cout << i << " " << std::flush;
	}
	out.output_end();
	std::cout << std::endl;
}

int main()
{
	// test_fixed();

	font_t font("s2513.d2");

	// asm_output out;
	img_output out( font );

	place_t p1(-0.61,0,19,24);
	place_t p2(-1.04,-0.33,1,1);
	place_t p3(-1.38,0.123,1,1);
	place_t p4(-1.47,0,1,1);
	place_t p5(-0.62,-0.45,1,1);

	place_t j0(0,0,25,40);
	place_t j1(0.8,0,12,20);

	place_t p0(-0.61,0,1,1,576,512);
	// mandel( p0, out );


	// mandel( p1, out );
	// mandel( p2, out );
	// mandel( p3, out );
	// mandel( p4, out );
	// mandel( p5, out );
	// julia( j1, -0.8, 0.156, out );
	// julia( j0, -0.8, 0.156, out );
	// julia( j1, -0.55,-0.64, out );

	place_t j_large(0,0,1,1,1024,1024);

	for (int i=32;i!=0;i/=2)
	{
		place_t pl( 0,0,i,i,1024/i,1024/i );
		mandel( pl, out );
	}

	for (int i=32;i!=0;i/=2)
	{
		place_t pl( 0,0,i,i,1024/i,1024/i );
		julia( pl, -0.8, 0.156, out );
	}

	for (int i=32;i!=0;i/=2)
	{
		place_t pl( 0,0,i,i,1024/i,1024/i );
		julia( pl, -0.55, -0.64, out );
	}

	for (int i=32;i!=0;i/=2)
	{
		place_t pl( 0,0,i,i,1024/i,1024/i );
		julia( pl, 0.27, 1.0/256, out );
	}

	// julia( j_large, -0.8, 0.156, out );
	// julia( j_large, -0.55, -0.64, out );
	// julia( j_large, 0.27, 1.0/256, out );

	return 0;
}