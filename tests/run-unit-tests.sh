#!/bin/bash
set -euo pipefail

build_dir="$(mktemp -d)"
trap 'rm -rf "$build_dir"' EXIT

swiftc Modules/Kimai/Sources/Core/CustomerSearch.swift tests/kimai/customer-search.swift -o "$build_dir/customer-search"
"$build_dir/customer-search"

swiftc Modules/Kimai/Sources/Core/HomeState.swift tests/today/home-state.swift -o "$build_dir/home-state"
"$build_dir/home-state"

swiftc Components/Report/Domain/ReportChartData.swift tests/report/chart-data.swift -o "$build_dir/chart-data"
"$build_dir/chart-data"

swiftc Components/Report/Domain/ReportTimelineLayout.swift tests/report/timeline-layout.swift -o "$build_dir/timeline-layout"
"$build_dir/timeline-layout"

PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests/ui -p '*test.py'
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests/project -p '*test.py'
