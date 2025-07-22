CXX=g++
CXXSTD=-std=c++11
CXXFLAGS=$(CXXSTD) -Wall -Wextra -pedantic -g -fPIC
LDFLAGS=-shared

all: pifo.so

pifo.so:
	$(CXX) $(CXXFLAGS) $(LDFLAGS) pifo.cpp -o $@

clean:
	rm -rf pifo.so	
	rm -rf pifo.o	
	rm -rf pifo.lo	
