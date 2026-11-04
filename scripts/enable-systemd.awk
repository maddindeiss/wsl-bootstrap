# Merge systemd=true into [boot], preserving unrelated settings and comments.
function finish_boot() {
    if (in_boot && !seen_systemd) print "systemd=true"
}

{
    line = $0
    sub(/\r$/, "", line)
    if (line ~ /^[[:space:]]*\[/) {
        finish_boot()
        section = line
        sub(/[;#].*$/, "", section)
        in_boot = tolower(section) ~ /^[[:space:]]*\[boot\][[:space:]]*$/
        if (in_boot) found_boot = 1
        seen_systemd = 0
    }
    if (in_boot && tolower(line) ~ /^[[:space:]]*systemd[[:space:]]*=/) {
        # Keep just one active assignment in this section.
        if (!seen_systemd) {
            value = line
            sub(/^[^=]*=[[:space:]]*/, "", value)
            sub(/[[:space:]]*([;#].*)?$/, "", value)
            if (value == "true") {
                print $0
            } else {
                comment = ""
                if (match(line, /[;#]/)) comment = " " substr(line, RSTART)
                print "systemd=true" comment
            }
        }
        seen_systemd = 1
        next
    }
    print $0
}

END {
    finish_boot()
    if (!found_boot) {
        if (NR) print ""
        print "[boot]"
        print "systemd=true"
    }
}
