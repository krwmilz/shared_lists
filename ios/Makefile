#
# the sdk needs to be unpacked and ready to go before running this, see
# http://iphonedevwiki.net/index.php/Compiling_iOS_applications_on-device
# for more information
#

CC=clang
CFLAGS=-isysroot /var/sdks/Latest.sdk
LDFLAGS=-framework Foundation -framework UIKit

OBJS=main.o TestLabel.o

.SUFFIXES: .m .o

Shist: $(OBJS)
	$(CC) $(CFLAGS) $(LDFLAGS) $(OBJS) -o $@

.m.o:
	$(CC) $(CFLAGS) -c $<

$(OBJS): TestLabel.h

clean:
	rm -f *.o Shist
