#!/usr/bin/env python3
import argparse
import sys
import re
from collections import Counter

def main():
    parser = argparse.ArgumentParser(description="단어 수 및 빈출 단어 출력 도구")
    parser.add_argument("text", nargs="?", help="분석할 텍스트 (생략 시 stdin)")
    args = parser.parse_args()

    text = args.text if args.text is not None else sys.stdin.read()

    words = re.sub(r"[^\w\s]", "", text.lower()).split()

    if not words:
        print("입력된 단어가 없습니다. 텍스트를 제공해주세요.")
        return

    print(f"총 단어 수: {len(words)}")
    for word, count in Counter(words).most_common(3):
        print(f"  {word}: {count}회")

if __name__ == "__main__":
    main()
