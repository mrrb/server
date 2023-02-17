#!/usr/bin/python3

import sys

if __name__ == "__main__":
  if len(sys.argv) <= 1:
    exit

  files = sys.argv[1:]

  matches = []

  for file_name in files:
    f = open(file_name)

    file_matches = []
    for line in f:    
      while True:
        m = line.find('${')

        if m < 0:
          break
        else:
          file_matches.append(line[m:])
          line = line[m+1:]

    matches += [m.lstrip('${').split(':')[0].split('}')[0]
                for m in file_matches]
    f.close()

  matches = list(set(matches))
  matches.sort()
  # print(set(matches))

  for m in matches:
    print(f"{m}=")
