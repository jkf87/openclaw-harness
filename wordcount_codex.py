#!/usr/bin/env python3
"""Word counter: counts total words and shows top 3 most frequent words."""

import argparse
import re
import sys
from collections import Counter


def count_words(text: str) -> None:
    """Count words and display results."""
    words = re.findall(r"[a-zA-Z]+(?:'[a-zA-Z]+)?", text.lower())
    if not words:
        print("입력이 비어 있습니다. 텍스트를 제공해주세요.")
        return

    freq = Counter(words)
    print(f"총 단어 수: {len(words)}")
    print("상위 3개 빈출 단어:")
    for word, count in freq.most_common(3):
        print(f"  {word}: {count}회")


def main():
    parser = argparse.ArgumentParser(
        description="텍스트의 단어 수를 세고 상위 3개 빈출 단어를 출력합니다."
    )
    parser.add_argument("text", nargs="*", help="분석할 텍스트 (생략 시 stdin 사용)")
    parser.add_argument(
        "-f", "--file", type=argparse.FileType("r"), help="입력 파일 경로"
    )
    args = parser.parse_args()

    if args.file:
        text = args.file.read()
    elif args.text:
        text = " ".join(args.text)
    else:
        text = sys.stdin.read()

    count_words(text)


if __name__ == "__main__":
    main()
