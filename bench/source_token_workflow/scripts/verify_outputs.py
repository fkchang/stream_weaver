from html.parser import HTMLParser
from pathlib import Path


class VisibleText(HTMLParser):
    def __init__(self):
        super().__init__()
        self.hidden = 0
        self.parts = []

    def handle_starttag(self, tag, attrs):
        if tag in {"script", "style"}:
            self.hidden += 1
        for name, value in attrs:
            if name == "aria-label" and value:
                self.parts.append(value)

    def handle_endtag(self, tag):
        if tag in {"script", "style"}:
            self.hidden -= 1

    def handle_data(self, data):
        if not self.hidden:
            self.parts.append(data)

    def text(self):
        return " ".join(" ".join(self.parts).split())


root = Path(__file__).resolve().parents[1]
output = root / "tmp" / "rendered"
implementations = ["streamweaver", "plain", "react"]
always = ["Release readiness", "4", "Ready", "2", "Review", "1", "Blocked", "Navigation", "Web", "Today", "Source inspection", "Docs", "Mobile layout", "Design", "Tomorrow", "Release checklist", "Ops", "Friday"]

for implementation in implementations:
    for version in ["initial", "revised"]:
        path = output / f"{implementation}-{version}.html"
        parser = VisibleText()
        parser.feed(path.read_text(encoding="utf-8"))
        text = parser.text()
        folded = text.casefold()
        missing = [value for value in always if value.casefold() not in folded]
        if missing:
            raise SystemExit(f"{path.name}: missing {missing}")
        if version == "initial":
            if "ON TRACK" not in text.upper() or "ACTION NEEDED" in text.upper() or "status" in folded:
                raise SystemExit(f"{path.name}: initial badge/table mismatch")
        else:
            if "ACTION NEEDED" not in text.upper() or "status" not in folded:
                raise SystemExit(f"{path.name}: revised badge/status mismatch")
        print(f"verified {path.name}")
