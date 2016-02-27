apnd: apnd.go src
	GOPATH=`pwd` go build

src:
	# Automatically download dependencies listed in source files
	GOPATH=`pwd` go get -d

clean:
	# Delete output from make depend too
	rm -rf apnd src
