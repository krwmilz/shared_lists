#
# the sdk needs to be unpacked and ready to go before running this, see
# http://iphonedevwiki.net/index.php/Compiling_iOS_applications_on-device
# for more information
#

CC=clang
CFLAGS=-isysroot /var/sdks/iPhoneOS7.1.sdk
LDFLAGS=-framework Foundation -framework UIKit

PROG=shlist
OBJS=main.o ViewController.o

.SUFFIXES: .m .o

$(PROG): $(OBJS)
	$(CC) $(CFLAGS) $(LDFLAGS) $(OBJS) -o $@
	cp $@ /Applications/$(PROG).App/
	killall -HUP SpringBoard

.m.o:
	$(CC) $(CFLAGS) -c $<

$(OBJS): ViewController.h

open:
	open net.iphonedevwiki.shlist

clean:
	rm -f *.o $(PROG)
