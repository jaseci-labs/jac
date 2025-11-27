#!/bin/bash
DAYS=${1:-7}
echo "Top contributors in the last $DAYS days:"
git log --since="$DAYS days ago" --pretty=format:"%an|%ae|%as" | \
awk -F'|' -v days="$DAYS" '
{
    author = $1
    emails[author] = $2
    count[author]++

    day_key = author SUBSEP $3
    if (!(day_key in seen_days)) {
        seen_days[day_key] = 1
        active_days[author]++
    }
}
END {
    for (author in count) {
        printf "%-20s (%s): %d commits, %d/%s active days\n", author, emails[author], count[author], active_days[author], days
    }
}' | sort -t':' -k2 -nr
