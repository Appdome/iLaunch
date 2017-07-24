CC := clang
LD := clang # Requires less arguments
CFLAGS += -g -fobjc-arc
LDFLAGS += -Wl,-rpath,/tmp/.xcodelib1,-rpath,/tmp/.xcodelib2,-rpath,/tmp/.xcodelib3 -framework Foundation -g

ilaunch: main.m.o xcode.m.o
	$(LD) -o $@ $^ $(LDFLAGS)
	
%.m.o: %.m
	$(CC) -c -o $@ $^ $(CCFLAGS)
	
clean:
	-rm -rf ilaunch *.o *.dSYM
	
install: ilaunch
	cp $^ /usr/local/bin/