import argparse
import subprocess
from shutil import copyfile
import os.path
import re

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--student_dir'
    , help='Directory where student\'s makefile and project is located.'
    , required=True)
    args = parser.parse_args()

    # Let's make the program first
    makeCmd = ['make', '-C', args.student_dir, 'micaz', 'sim']
    subprocess.call(makeCmd)

    # Copy the TOSSIM file
    sharedObject = '_TOSSIMmodule.so'
    simFilename =os.path.join(args.student_dir, sharedObject)
    copyfile(simFilename, './'+sharedObject)

if __name__ == '__main__':
    main()
