import sys

if (len(sys.argv) != 3):
    print("Usage: compile_font.py [input.txt] [output.bin]", file=sys.stderr)
    sys.exit(1)

f = open(sys.argv[1], "r")

line = 1

char_list = dict()

while(charhead := f.readline()):
    if (len(charhead) != 3):
        raise ValueError("'{}' is not a valid char header".format(charhead.rstrip('\n')))
    char = charhead[0]
    result = []
    for i in range(0, 8):
        s = f.readline()
        b = 0;
        for j in range(0, 8):
            b <<= 1
            b |= 1 if len(s) > j and s[j] == 'X' else 0
        result.append(b)
    char_list[char] = result
    line += 1

with open(sys.argv[2], "wb") as output:
    for i in range(0, 0x100):
        if (char_list.get(chr(i))):
            output.write(bytes(bytearray(char_list[chr(i)])))
        else:
            output.write(bytes(bytearray([0,0,0,0,0,0,0,0])))
