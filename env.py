#!/usr/bin/python3

import argparse

if __name__ == "__main__":
  parser = argparse.ArgumentParser(
      description='Gen environment file from yaml files.', add_help=True)
  parser.add_argument('-s', '--set-values',
                      action='store_true',
                      dest='set_value',
                      help='Set the default variable values for the environment file'
                      )
  parser.add_argument('-v', '--values-file',
                      dest='values_file',
                      help='JSON file with the default variable values',
                      type=str
                      )
  parser.add_argument('-e', '--extra-values-file',
                      dest='extra_values_file',
                      help='JSON file with extra variable values',
                      type=str
                      )
  parser.add_argument('-E', '--extra-env-pair',
                      nargs='+',
                      dest='extra_env_pair',
                      help='Extra environment pair KEY=VALUE',
                      type=str
                      )
  parser.add_argument('files',
                      nargs='+',
                      help='YAML files',
                      type=str
                      )

  args = parser.parse_args()

  matches = []

  for file_name in args.files:
    with open(file_name) as f:
      file_matches = []
      for line in f:    
        while True:
          m = line.find('${')

          if m < 0:
            break
          elif m > 0 and line[m-1] == '$':
            break
          else:
            file_matches.append(line[m:])
            line = line[m+1:]

      matches += [m.lstrip('${').split(':')[0].split('}')[0]
                  for m in file_matches]

  env_data = {}
  if args.set_value:
    try:
      import json

      values_file = args.values_file
      if not values_file:
        values_file = './env.json'

      with open(values_file) as data:
        env_data = json.load(data)

      extra_values_file = args.extra_values_file
      if extra_values_file:
        with open(extra_values_file) as data:
          env_data = env_data | json.load(data)
    except:
      pass

  extra_env_data = {}
  if args.extra_env_pair:
    for eep in args.extra_env_pair:
      try:
        key, value = eep.split('=')
        extra_env_data[key] = value
      except:
        pass

  env_data = {**extra_env_data, **env_data}

  matches += list(extra_env_data.keys())
  matches = list(set(matches))
  matches.sort()

  for m in matches:
    print(f"{m}={env_data.get(m) if env_data.get(m) else ''}")
