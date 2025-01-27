BEGIN {
    print "\"firstname\",\"lastname\",\"email\",\"affiliation\",\"country\",\"username\",\"tempPassword\",\"role1\"";
}
NR > 1 {
    printf "\"%s\",\"%s\",\"%s\",\"%s\",\"%s\",%s,\"%s\",\"%s\"\n", $1, $2, $3 ? $3 : $6"@nk.ro", $4 ? $4 : "NK4 " $6, $5, $6, $7, $8;
}
# gawk -k -f field_content_add.awk baza_quoted_header_normalizing_names.csv > baza_quoted_header_normalizing_names-completed.csv
# mlr --csv --quote-all -N unsparsify baza_quoted_header_normalizing_names-completed.csv > baza_quoted_header_normalizing_names-completed_quoted.csv
