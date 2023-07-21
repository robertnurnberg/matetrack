import argparse
import matplotlib.pyplot as plt
import matplotlib.dates as mdates
from datetime import datetime


class matedata:
    def __init__(self, prefix):
        self.prefix = prefix
        self.lines = []
        with open(prefix + ".csv") as f:
            for line in f:
                self.lines.append(line)

        self.matescores = {}
        with open("matecorrect1000000.csv") as f:
            for line in f:
                line = line.strip()
                if line.startswith("Commit"):  # ignore the header
                    continue
                if line:
                    parts = line.split(",")
                    if parts[2]:  # ignore skipped commits
                        sha = parts[1]
                        self.matescores[sha] = parts[2:-1]

        # hard code the best mates from difference.epd, and if fens were removed
        self.bestmates = [10, 11, 12, 16, 19, 25]
        self.removed = [True] * 5 + [False]

    def get_changes(self, sha):
        # compute changes in mates and bestmates for given sha
        scores = self.matescores[sha]
        changem = changebm = 0
        for i, bm in enumerate(self.bestmates):
            if scores[i] != "None":
                self.statsm[i] += 1
                if self.removed[i]:
                    changem -= 1
                if int(scores[i]) == self.bestmates[i]:
                    self.statsbm[i] += 1
                    if self.removed[i]:
                        changebm -= 1
                    else:
                        # this needs also old (incorrect) bm value (here: 26)
                        assert False, "Not implemented yet"
        return changem, changebm

    def correct(self):
        self.statsm = [0] * 6
        self.statsbm = [0] * 6
        for i, line in enumerate(self.lines):
            line = line.strip()
            if line.startswith("Commit"):  # ignore the header
                continue
            if line:
                parts = line.split(",")
                if parts[2]:  # ignore skipped commits
                    sha = parts[1]
                    if sha in self.matescores:
                        changem, changebm = self.get_changes(sha)
                        total = int(parts[2]) - sum(self.removed)
                        mates = int(parts[3]) + changem
                        bmates = int(parts[4]) + changebm
                        tag = parts[5]
                        line = ",".join(
                            parts[:2] + [str(total), str(mates), str(bmates), tag]
                        )
                        self.lines[i] = line + "\n"

    def write(self, filename):
        with open(filename, "w") as f:
            for line in self.lines:
                f.write(line)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Correct data stored in matetrack1000000.csv based on matecorrect1000000.csv for difference.epd (needs hard coding of bm and if removed).",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument(
        "filename",
        nargs="?",
        help="file with statistics over time",
        default="matetrack1000000.csv",
    )
    args = parser.parse_args()

    prefix, _, _ = args.filename.partition(".csv")
    data = matedata(prefix)
    data.correct()
    data.write("corrected.csv")
    print("Total number of mates in changed positions: ", data.statsm)
    print("Total number of best mates in changed positions: ", data.statsbm)
