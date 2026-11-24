from dataclasses import dataclass
from math import isfinite
from .gallery import Gallery


@dataclass(frozen=True)
class MatchResult:
    member_id: str | None  # None: nobody matched confidently.
    score: float  # Best cosine score, -1.0 for an empty gallery.
    margin: float  # Best minus second best; 1.0 when only one member exists.


class Matcher:
    """1:N decision: best score must pass a threshold AND clearly beat the runner-up.

    Defaults are NOT calibrated. Choose them from measured FAR/FRR on consented data.
    """

    def __init__(self, gallery: Gallery, threshold: float = 0.5, margin: float = 0.05):
        if not (isfinite(threshold) and -1 < threshold < 1) or not (isfinite(margin) and 0 <= margin < 1):
            raise ValueError("threshold must be in (-1, 1) and margin in [0, 1)")
        self.gallery, self.threshold, self.margin = gallery, threshold, margin

    def match(self, embedding) -> MatchResult:
        ranked = self.gallery.search(embedding)
        if not ranked:
            return MatchResult(None, -1.0, 0.0)
        best_id, best = ranked[0]
        gap = best - ranked[1][1] if len(ranked) > 1 else 1.0
        accepted = best >= self.threshold and gap >= self.margin
        return MatchResult(best_id if accepted else None, best, gap)
