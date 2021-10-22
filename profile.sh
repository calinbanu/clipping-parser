#!/bin/bash

OUTPUT_DIR="profile"
TOOL="grcov"
FORMAT="html"
RUN_OPTIONS=""

while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    -o|--output)
      OUTPUT_DIR="$2"
      shift # past argument
      shift # past value
      ;;
    -t|--tool)
      TOOL="$2"
      shift # past argument
      shift # past value
      ;;
    -f|--format)
      FORMAT="$2"
      shift
      shift
      ;;
    --)    # unknown option
      shift
      while [[ $# -gt 0 ]]; do
        RUN_OPTIONS+="$1 " # save it in an array for later
        shift
      done
      ;;
    *)
      echo "Invalid option: $1"
      exit 1
      ;;
  esac
done

PROFRAW_FILE=$OUTPUT_DIR/data.profraw
PROFDATA_FILE=$OUTPUT_DIR/data.profdata

export LLVM_PROFILE_FILE=$PROFRAW_FILE
export RUSTFLAGS="-Z instrument-coverage"

rm -rf $OUTPUT_DIR
mkdir $OUTPUT_DIR
#cargo clean

BINARY_NAME=$(cargo +nightly metadata --no-deps --format-version 1 | sed 's/.*,"name":"\([a-zA-Z0-9_-]*\)","src_path":.*/\1/')

if [[ "$TOOL" == "cov" ]]; then
  cargo +nightly run -- $RUN_OPTIONS
  cargo +nightly profdata -- merge -sparse $PROFRAW_FILE -o $PROFDATA_FILE
  cargo +nightly cov -- show \
    -Xdemangler=rustfilt \
    -instr-profile=$PROFDATA_FILE \
    -output-dir=$OUTPUT_DIR \
    -format=$FORMAT \
    -ignore-filename-regex='.*\.cargo.*' \
    -show-instantiations \
    -show-expansions \
    -show-line-counts-or-regions \
    target/debug/$BINARY_NAME
  rm -f $PROFRAW_FILE
  rm -f $PROFDATA_FILE
elif [[ "$TOOL" == "grcov" ]]; then
  cargo +nightly run -- $RUN_OPTIONS

  if [[ "$FORMAT" == "lcov" ]]; then
    OUTPUT_DIR=$OUTPUT_DIR/lcov.info
  fi

  if [[ "$FORMAT" == "cobertura" ]]; then
      OUTPUT_DIR=$OUTPUT_DIR/cobertura.info
  fi

  grcov $PROFRAW_FILE --binary-path target/debug/ -s . -t $FORMAT --branch --ignore-not-existing -o $OUTPUT_DIR
  rm -f $PROFRAW_FILE
else
  echo "Invalid type: $TOOL"
  exit 1
fi
