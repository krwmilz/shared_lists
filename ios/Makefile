#
# the sdk needs to be unpacked and ready to go before running this, see
# http://iphonedevwiki.net/index.php/Compiling_iOS_applications_on-device
# for more information
#

build: main.m TestLabel.m
	clang -isysroot /var/sdks/Latest.sdk -c main.m
	clang -isysroot /var/sdks/Latest.sdk -c TestLabel.m
	clang -isysroot /var/sdks/Latest.sdk -framework Foundation \
	       -framework UIKit main.o TestLabel.o -o Shist

install: build
	cp Shist /Applications/Shist.app/

clean:
	rm -f *.o Shist
