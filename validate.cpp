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
#include <cmath>

const int ISIZE=3;
const int ISIZE_MAX=(1 << ISIZE) - 1;
const int FSIZE=8;
const int FSIZE_MAX=(1 << FSIZE) - 1;

class fixed_t;
std::ostream& operator<<(std::ostream& os, const fixed_t& f);

// A 11 bits fixed point class (3+8)
//	External sign + NaN
class fixed_t
{
	bool sign_;
	bool nan_;
    unsigned int integer_ : ISIZE;
    unsigned int fractional_ : FSIZE;

public:
	fixed_t() : sign_(false), integer_(0), fractional_(0), nan_(false) {}

	fixed_t(bool sign, int integer, int fractional, bool nan=false) : sign_(sign), integer_(integer), fractional_(fractional), nan_(nan)
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
			*this = nan();
			return;
		}
		*this = fixed_t(sign, integer, fractional,false);
// printf( "%s\n", to_string().c_str() );
	}

	static fixed_t nan() { return fixed_t(false,0,0,true); }
	static fixed_t epsilon( int count=1 ) { return fixed_t(0, count); }

    std::array<uint8_t, 2> get() const
    {
        return {static_cast<uint8_t>(integer_), static_cast<uint8_t>(fractional_)};
    }

	std::string to_string( bool verbose=true ) const
	{
		if (is_nan())
		{
			return "<NaN>";
		}
		// return (sign_ ? "-" : "") + std::to_string(integer_ + fractional_ / (FSIZE_MAX+1.0))+"("+std::to_string(integer_)+":"+std::to_string(fractional_)+")";
		if (!verbose)
			return (sign_ ? "-" : "") + std::to_string(integer_ + fractional_ / (FSIZE_MAX+1.0));
		return std::to_string(to_float())+"("+std::to_string(integer_)+":"+std::to_string(fractional_)+")";
	}

	std::string as_asm( const std::string separator=" ", const std::string prefix="" ) const
	{
		if (nan_)
		{
			return prefix+"01"+separator+prefix+"00";
		}

		int16_t v0 = ((integer_ << FSIZE) | fractional_)<<1;

		v0 *= (sign_ ? -1 : 1);

		uint16_t v = v0;

		//	Return v as a 5 digits strings with the hex numbers, little endian
		char buffer[128];
		sprintf(buffer, "%s%02X%s%s%02X", prefix.c_str(), v&0xff, separator.c_str(), prefix.c_str(), v>>8);
		return buffer;
	}

	float to_float() const
	{
		assert( !is_nan() );
		return (sign_ ? -1 : 1) * (integer_ + fractional_ / (FSIZE_MAX+1.0));
	}

	fixed_t set_sign(bool sign) const
	{
		return fixed_t(sign, integer_, fractional_,nan_);
	}

	bool is_nan() const
	{
//		return integer_ == ISIZE_MAX && fractional_ == FSIZE_MAX;
		return nan_;
	}	

	fixed_t times_positive( fixed_t other) const
	{
		if (is_nan() || other.is_nan())
		{
			return nan();
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
		assert( !is_nan() );
		assert( !other.is_nan() );
		return sign_ == other.sign_ && integer_ == other.integer_ && fractional_ == other.fractional_;
	}

	bool operator!=(const fixed_t& other) const
	{
		return !(*this == other);
	}

	fixed_t operator-() const
	{
		return fixed_t(!sign_, integer_, fractional_,nan_);
	}

	fixed_t abs() const
	{
		return fixed_t(false, integer_, fractional_,nan_);
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
			return nan();
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
			return nan();
		}
		return fixed_t(integer, fractional);
	}

	fixed_t operator+(const fixed_t& other) const
	{
		// std::cout << "ADD " << *this << " + " << other << std::endl;

		if (is_nan() || other.is_nan())
		{
			return nan();
		}

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
		assert( !is_nan() );

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
		if (x2.is_nan())
		{
			return nan();
		}
		auto y2 = y.squared();
		if (y2.is_nan())
		{
			return nan();
		}
		auto xmy2 = (x - y).squared();
//### WARN CHANGED
		// if (x<y)
		// 	return y2-xmy2+x2;
		// return x2-xmy2+y2;
		return -xmy2 + x2 + y2;
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
	assert( fixed_t::nan().times(fixed_t(1, 0)).is_nan() );
	assert( fixed_t::nan().times(fixed_t(0, 1)).is_nan() );
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
	assert( (fixed_t::nan() + fixed_t(1)).is_nan() );
	assert( (fixed_t::nan() + fixed_t::nan()).is_nan() );
	assert( (fixed_t::nan() + fixed_t::epsilon()).is_nan() );

	//	Test we get to saturation
	assert( fixed_t(ISIZE_MAX) + fixed_t::epsilon() == fixed_t(ISIZE_MAX,1) );
	assert( (fixed_t(ISIZE_MAX) + fixed_t(1)).is_nan() );

	//	Iterate from 0 to max by eplison steps
	fixed_t f(0);
	while (!f.is_nan())
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
		expected = fixed_t::nan();
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
	assert( (fixed_t(1).mul2(fixed_t(3))).is_nan() );
	assert( (fixed_t(2).mul2(fixed_t(2))).is_nan() );
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
	while (!f.is_nan())
	{
		fixed_t g(0);
		while (!g.is_nan())
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

	/*	Intensity of each 4x4 block
		i0 i1
		i2 i3
	*/

	int i0_[64];
	int i1_[64];
	int i2_[64];
	int i3_[64];
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

		for (int i=0;i!=64;i++)
			i0_[i] = i1_[i] = i2_[i] = i3_[i] = 0;

		for (int i=0;i!=64;i++)
		{
			for (int line=0;line!=4;line++)
			{
				int v = font_[i*8+line];
				for (int j=0;j!=4;j++)
				{
					i0_[i] += v&1;
					v >>= 1;
				}
				for (int j=0;j!=4;j++)
				{
					i1_[i] += v&1;
					v >>= 1;
				}
			}
			for (int line=4;line!=8;line++)
			{
				int v = font_[i*8+line];
				for (int j=0;j!=4;j++)
				{
					i2_[i] += v&1;
					v >>= 1;
				}
				for (int j=0;j!=4;j++)
				{
					i3_[i] += v&1;
					v >>= 1;
				}
			}
		}
	}

	const uint8_t *get( int c ) const
	{
		c %= size;
		return font_+c*height;
	}

	int dist( int c, int i0, int i1, int i2, int i3 ) const
	{
		c %= size;
		int d0 = std::abs(i0_[c]-i0);
		int d1 = std::abs(i1_[c]-i1);
		int d2 = std::abs(i2_[c]-i2);
		int d3 = std::abs(i3_[c]-i3);
		return d0+d1+d2+d3;
	}

	const u_int8_t best( int i0, int i1, int i2, int i3 ) const
	{
		i0 = std::max( i0, 4 )-4;
		i1 = std::max( i1, 4 )-4;
		i2 = std::max( i2, 4 )-4;
		i3 = std::max( i3, 4 )-4;

		i0 /= 4;
		i1 /= 4;
		i2 /= 4;
		i3 /= 4;
		if (i0>16) i0 = 16;
		if (i1>16) i1 = 16;
		if (i2>16) i2 = 16;
		if (i3>16) i3 = 16;

		// Find best character match
		int best = 0;
		int best_dist = dist(0, i0, i1, i2, i3);
		for (int i=1;i!=size;i++)
		{
			int d = dist(i, i0, i1, i2, i3);
			if (d<best_dist)
			{
				best = i;
				best_dist = d;
			}
		}

		return best;
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
		ss << "x= " << x_ << " y= " << y_ << " rx= " << rx_ << " ry= " << ry_ << "\n";
		ss << "x= " << x_.as_asm() << " y= " << y_.as_asm() << " rx= " << rx_.as_asm() << " ry= " << ry_.as_asm();
		return ss.str();
	}
};

int iter( fixed_t x, fixed_t y, fixed_t zx, fixed_t zy )
{
	fixed_t zx2 = zx.squared();
	fixed_t zy2 = zy.squared();
	int i = 0;
	while (i < 250 && !(zx2 + zy2).is_nan())
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
	std::cout << place.description() << "\n";
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

void mandelhr( const place_t &place, ioutput &out, const font_t &font )
{
	auto placehr = place;
	placehr.rx_ = place.rx_.div2();
	placehr.ry_ = place.ry_.div2();

	out.output_start( place.description(), place.w_, place.h_ );
	auto y = place.y_;
	for (int i=0;i!=place.h_;i++)
	{
		auto x = place.x_;
		for (int j=0;j!=place.w_;j++)
		{
			auto x0 = x;
			auto y0 = y;
			auto x1 = x + placehr.rx_;
			auto y1 = y + placehr.ry_;

			int it0 = iter(x0,y0,x0,y0);
			int it1 = iter(x1,y0,x0,y1);
			int it2 = iter(x0,y1,x1,y0);
			int it3 = iter(x1,y1,x1,y1);

			out.output( font.best( it0, it1, it2, it3 ), x, y );		

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

//	Generates test cases for the ASM version of ADD and SUB
void gen_tests()
{
		std::cout << "TESTDATA" << ":" << std::endl;
	//	Generates 100 pairs of fixed_t
	for (int i=0;i!=100;i++)
	{
			// a random number between -8 and 8
		float f0 = (rand()%16000)/1000.0-8;
		float f1 = (rand()%16000)/1000.0-8;
		fixed_t n0 = fixed_t(f0);
		fixed_t n1 = fixed_t(f1);
		std::cout << ".byte " << n0.as_asm(",","$") << "," << n1.as_asm(",","$") << "," << (n0+n1).as_asm(",","$")
			<< "	;  " << n0.to_string(false) << " + " << n1.to_string(false) << " = " << (n0+n1).to_string(false) << std::endl;
	}
}

int main( int argc, char **argv )
{

	if (argc==2)
	{
		fixed_t f(atof(argv[1]));
		std::cout << f.as_asm() << std::endl;
		exit(0);
	}

	iter(fixed_t(-1.5),fixed_t(-1),fixed_t(-1.5),fixed_t(-1));

	test_fixed();


	gen_tests();
	// exit(0);
	//
	{
		int num = 0;
		int inc = 0;
		int adrs = 4096;

		for (int i=0;i!=800;i++)
		{
			printf( "%04X : %02X %02X %02X   %02X %02X %02X => %02X %02X\n", adrs, num&0xff, (num>>8)&0xff, (num>>16)&0xff, inc&0xff, (inc>>8)&0xff, (inc>>16)&0xff, ((num>>8)&0x7f)<<1, (((num>>8)&0x780)>>7)|0x10 );

			num += inc;
			inc++;
			num += inc;

			// if (adrs%16==0)
			// 	printf( "\n%04X: ", adrs );
			// uint16_t v = num>>8;
			// printf( "%02X %02X ", (v&0x7f)<<1, ((v&0x780)>>7)|0x10 );

			adrs += 2;


		}
		printf( "\n\n");
	}

	// find max square
#if 0
	fixed_t sq(0);
	int adrs = 4096;
	for (int i=0;i!=2048;i++)
	{
		auto sq2 = sq.squared();

		if (adrs%16==0)
			std::cout << std::endl << std::hex << adrs << " " << std::dec << ": ";
		adrs += 2;

		std::cout << sq2.as_asm() << " ";
		if (sq2.is_nan())
		{
			std::cout << "Last square = " << i-1 << std::endl;
			exit(0);
		}
		sq = sq + fixed_t::epsilon();
	}
#endif

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

 mandel( p1, out );

	// mandel( p1, out );
	// mandel( p2, out );
	// mandel( p3, out );
	// mandel( p4, out );
	// mandel( p5, out );
	// julia( j1, -0.8, 0.156, out );
	// julia( j0, -0.8, 0.156, out );
	// julia( j1, -0.55,-0.64, out );

	place_t j_large(0,0,1,1,1024,1024);

	for (int i=32;i!=1;i/=2)
	{
		place_t pl( 0,0,i,i,1024/i,1024/i );
		mandelhr( pl, out, font );
	}

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
