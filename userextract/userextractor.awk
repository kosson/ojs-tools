@include "./make_password"
BEGIN {
    print "\"firstname\",\"lastname\",\"email\",\"affiliation\",\"country\",\"username\",\"tempPassword\",\"role1\"";
}
NR > 1 {
    split($4, arr_names, ";"); # $4 is authors
    split($5, arr_affil, ";"); # $5 is affiliations
    
    if (length($16) > 0 ) 
        split($16, arr_email, ";"); # $16 is emails

    for (i in arr_names) {
        split(arr_names[i], n_p_arr, ",");
        firstname = tolower(n_p_arr[1]);
        lastname = tolower(n_p_arr[2]);
        both_strs = firstname"_"lastname;
        gsub(/-/, "_", both_strs); # if you find a - in the name
        gsub(/ +/, "_", both_strs); # if you find a space in the name
        cmd = "echo \"" both_strs "\" | iconv --verbose -f utf-8 -t ascii//TRANSLIT"; 
        cmd | getline username;
        printf "\"%s\",\"%s\",\"%s\",\"%s\",\"%s\",%s,\"%s\",\"%s\"\n",  n_p_arr[1], n_p_arr[2], arr_email[i], arr_affil[i], "", username, generate_password(10), "Author";     
        close(cmd);
    }
}
# gawk -k -f userextractor.awk 2022-preluare-date-v1-quoted.csv > refined.csv