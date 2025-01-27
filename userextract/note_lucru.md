# Note de ETL pentru useri

## Transformare date CSV folosind GAWK

```awk
name_splitted=split(arr_names[i], arr_name_s, ",");
        printf "%s,%s,%s\n", arr_name_s[0], arr_name_s[1], arr_affil[i];
        
    # Dacă firstname este un nume complex separat prin spații
    if(split(firstname, fname_arr, " ") > 1){
        concatfirstname = ""
        for(i in fname_arr){
            concatfirstname = concatfirstname lower_case(fname_arr[i])
            firstname=concatfirstname
        }
    }
    # Dacă firstname este un nume complex separat prin cratimă
    if(split(firstname, fname_arr, "-") > 1){
        concatfirstname = ""
        for(i in fname_arr){
            concatfirstname = concatfirstname lower_case(fname_arr[i])
            firstname=concatfirstname
        }
    }   
    
function username_generator(firstname, lastname){
    # În cazul în care nu am valori, returnează un șir vid
    if (firstname == "" && lastname == "") {
        return ""
    }

    # Verifică dacă ori numele mic, ori numele mare sunt compuse fie prin spațiu, fie prin cratimă
    firstname = system(iconv -f utf-8 -t ascii//TRANSLIT)
    lastname = system(iconv -f utf-8 -t ascii//TRANSLIT)
    return "firstname_lastname";
}
```

### Sursă

Interesant: https://askubuntu.com/questions/1281117/how-to-pass-string-comand-to-shell-pipe-to-execute-it-output-of-awk

haha shell is so powerfull.. i can read top ips from apache access log and get the user agent for each the ip using the following (brute) command: cat /var/log/apache2/access.log | awk '{print $1}' | sort -n | uniq -c | sort -nr | head -20 | awk '{print "grep -F "$2" /var/log/apache2/access.log | tail -1" | "/bin/sh"}' | awk -v FPAT='([^ ]*)|("[^"]*")' '{print $10}'

https://askubuntu.com/questions/1281144/shell-awk-how-to-pass-some-value-across-to-results-of-another-command

I want to store the output of a bash command to a string in a bash script. 
https://askubuntu.com/questions/1143611/putting-output-of-command-into-a-string

2>&1 to pipe stderr to stdout.

## AWK: return value to shell script

### Sursa 1

https://stackoverflow.com/questions/9708028/awk-return-value-to-shell-script

You can also, of course, print the desired content in awk and put it into variables in bash by using read:

read a b c <<< $(echo "foo" | awk '{ print $1; print $1; print $1 }')
Now $a, $b and $c are all 'foo'. Note that you have to use the <<<$() syntax to get read to work. If you use a pipeline of any sort a subprocess is created too and the environment read creates the variables in is lost when the pipeline is done executing.

I had to change the command to `read -d '' a b c <<< $(echo "foo" | awk '{ print $1; print $1; print $1 }')`.

### Sursa 2

We all know stdin (&0), stdout (&1), and stderr (&2), but as long as you redirect it (aka: use it), there's no reason you can't use fd3 (&3).
The advantage to this method over other answers is that your awk script can still write to stdout like normal, but you also get the result variables in bash.
In your awk script, at the end, do something like this:

```awk
END {
  # print the state to fd3
  printf "SUM=%s;COUNT=%s\n", tot, cnt | "cat 1>&3"
}
```

Then, in your bash script, you can do something like this:

```bash
awk -f myscript.awk <mydata.txt 3>myresult.sh
source myresult.sh
echo "SUM=${SUM} COUNT=${COUNT}"
```

## Câteva idei:

- https://unix.stackexchange.com/questions/634976/pass-awk-variable-to-command-and-read-output
- https://stackoverflow.com/questions/42695143/run-command-inside-awk-and-store-result-inplace
- https://stackoverflow.com/questions/1960895/assigning-system-commands-output-to-variable
- https://www.linuxquestions.org/questions/programming-9/how-to-read-a-file-inside-awk-874908/

```awk
if ( (toascii | getline line) > 0 ) {
    close(cmd);
}
```

Backup al scriptului

```awk
BEGIN {
    print "\"firstname\",\"lastname\",\"email\",\"affiliation\",\"country\",\"username\",\"tempPassword\",\"role1\",\"role2\",\"role3\",\"role4\",\"reviewInterests\"";
}
function username_generator(firstname, lastname,  both_strs, cmd, toascii, toasciival){
    # Verifică dacă ori numele mic, ori numele mare sunt compuse fie prin spațiu, fie prin cratimă
    firstname = tolower(firstname);
    lastname = tolower(lastname);
    both_strs = firstname"_"lastname;
    cmd = "iconv --verbose -f utf-8 -t ascii//TRANSLIT";
    # toascii = system("echo \""both_strs"\" | "cmd) | getline line;
    toascii = system("echo \""both_strs"\" | "cmd " > tmp.txt"); # din nefericire trebuie recurs la acest artificiu pentru că nu poți captura output-ul.
    # toasciival = ( (toascii | getline line) > 0 ? line : "NaN" );
    close(cmd);
    return toascii;
}
NR > 1 {
    name_split=split($4, arr_names, ";");
    affil_split=split($5, arr_affil, ";");
    first_auth=$16; # este emailul
    for (i in arr_names) {
        nume_prenume_arr = split(arr_names[i], n_p_arr, ",");
        usr_name = username_generator(n_p_arr[1], n_p_arr[2]);
        op_result = getline line < "tmp.txt"; # preluarea rezultatului din fișier temporar
        system("rm -f tmp.txt"); # șterge fișierul pentru ca următorul apel să scrie unul proaspăt
        # printf -v all "\"%s\",\"%s\",\"%s\",\"%s\",\"%s\",\"%s\"\n",  n_p_arr[1], n_p_arr[2], first_auth, arr_affil[i], "", usr_name
        all = sprintf("\"%s\",\"%s\",\"%s\",\"%s\",\"%s\",\"%s\"\n",  n_p_arr[1], n_p_arr[2], first_auth, arr_affil[i], "", line);
        print all;
    }
}
```

gawk hangs when using a regex for RS combined with reading a continuous stream from stdin
https://stackoverflow.com/questions/78700014/gawk-hangs-when-using-a-regex-for-rs-combined-with-reading-a-continuous-stream-f

```bash
    # op_code = system("echo \""both_strs"\" | "cmd " > tmp.txt"); # din nefericire trebuie recurs la acest artificiu pentru că nu poți captura output-ul.
    # toasciival = ( (toascii | getline line) > 0 ? line : "NaN" );
    # if (op_code == 0) {
    #     getline line < "tmp.txt";
    #     print line;
    # } else {
    #     print op_code;
    # }
    # șterge fișierul creat
    # rm_cmd = "rm -f tmp.txt";
    # system(rm_cmd);
    # close(rm_cmd, "to");

    # line = "";
    # return line;
```

## STABIL, de lucru

Scriptul intermediar pentru crearea CSV-ului pentru useri. este varianta de dinainte de a cere ajutor pe StackOverflow.

```awk
@include "./make_password"
BEGIN {
    print "\"firstname\",\"lastname\",\"email\",\"affiliation\",\"country\",\"tempPassword\",\"role1\",\"username\"";
}
NR > 1 {
    split($4, arr_names, ";");
    split($5, arr_affil, ";");
    if ($16.length > 0 ) 
        first_auth[1]=$16; # este emailul primului autor

    for (i in arr_names) {
        split(arr_names[i], n_p_arr, ",");
        # username = username_generator(n_p_arr[1], n_p_arr[2]);
        # all = sprintf("\"%s\",\"%s\",\"%s\",\"%s\",\"%s\",\"%s\"\n",  n_p_arr[1], n_p_arr[2], first_auth, arr_affil[i], "", username);
        # print all;
        # Expresiile din stânga operatorului de atribuire sunt evaluate o singură dată.
        # linex = sprintf("\"%s\",\"%s\",\"%s\",\"%s\",\"%s\"",  n_p_arr[1], n_p_arr[2], first_auth[i], arr_affil[i], "");
        linex = sprintf("%s,%s,\"%s\",%s,\"%s\",\"%s\",%s",  n_p_arr[1], n_p_arr[2], first_auth[i], arr_affil[i], "", generate_password(10), "author");
        # username_generator(n_p_arr[1], n_p_arr[2], linex);
        
        firstname = tolower(n_p_arr[1]);
        lastname = tolower(n_p_arr[2]);
        both_strs = firstname"_"lastname;

        gsub(/-/, "_", both_strs); # înlocuirea cratimei din nume
        gsub(/ +/, "_", both_strs); # înlocuirea spațiului din nume

        printf("%s,%s", linex, username);
        # mai întâi trebuie să instanțiezi linia cu o variabilă care se va popula ulterior prin evaluarea lui getline (așa funcționează)
        # The getline command itself has a return value. If there is still output coming from the pipe, it returns 1. 
        # Returnează chestia asta: `sh: 1: 0: not found` după prima înregistrare
        cmd = "iconv --verbose -f utf-8 -t ascii//TRANSLIT";
        system("echo \""both_strs"\" | "cmd) | getline username;
        # while ( (("echo \""both_strs"\" | "cmd) | getline username) > 0) {
        #     print username;
        # }
        close(cmd);
    }
}
# gawk -k -f userextractor.awk 2022-preluare-date-v1-quoted.csv > refined.csv
```

## Ajutor pe stack overflow (mesajul)

https://stackoverflow.com/questions/79084009/avoiding-getline-in-gawk-used-to-solve-a-utf-8-to-ascii-transformation-in-a-csv

Dear all `awk` and `gawk` programmers.

I have a created the following script in `awk` after I have studied the language, and although I have solved my problem, I sense that the solution is not that clever. The problem is linked to the need to process a CSV file and get a new one reformated containing also rehashed data. The original CSV data looks like the following sample:

```csv
"issueTitle","sectionTitle","sectionAbbrev","authors","affiliation","DOI","articleTitle","year","datePublished","volume","issue","startPage","endPage","articleAbstract","galleyLabel","authorEmail","fileName","keywords","citations","cover_image_filename","cover_image_alt_text","licenseUrl","copyrightHolder","copyrightYear"
"Acta Hor...","Articles","ART","Ioana Marcela,Padure;Sanja,Simic","Universalmuseum Joanneum;Graz Centre for Electron Microscopy (ZFE)","","Sem studies regarding...","2022","2022-09-16","48","1","5","15","The paper presents the micromorphological...","PDF","acme@yahoo.com","AHB_48-1.pdf","SEM studies, micromorphology, fruit, seed, pollen, Hesperis, Brassicaceae","Ball, P.W. (1964). Hesperis L. In Tutin, T. G. et al. (eds). Flora Europaea. Vol. 1 (pp. 275-277). Cambridge University Press.","","","","Acta Hor...",""
"Acta Hor...","Articles","ART","Petronela,Camen-Comănescu","University of...","","First record of amaranthus viridis after over 25 years","2022","2022-09-11","48","1","17","23","We report the presence...","PDF","pet.acme@acme.ro","AHB_48-2.pdf","Amaranthus, alien plant, amaranth","Akeroyd J. R. (1993) Amaranthaceae, In T.G. Tutin et al (Eds.), Flora Europaea (ed. 2), Vol.1, pp. 130-132. Cambridge: Cambridge Univ. Press ","","","","Acta Hor...",""
"Acta Hor...","Articles","ART","Petronela,Camen-Comănescu;Daniela Clara,Mihai","University of..., Botanic Garden;University of..., Faculty of Biology","","Alien flora from B...","2022","2022-09-17","48","1","25","42","This paper presents the list...","PDF","pet.acme@acme.ro","AHB_48-3.pdf","alien plant species, allogenous, invasive species","Anastasiu, P. & Negrean, G. (2009). Neophytes in.... In L. Rákosy & L. Momeu (coord.). Neobiota (pp. 66-97). Edit. Presa Univ.","","","","Acta Hor...",""
"Acta Hor...","Articles","ART","Dalibor,Vladorić;Diana,Vlahović;Božena,Mitić","Natural History Museum and Zoo;Primary School Bogumila Tonija;Botanic Institute of PMF University of...","","Analysis of some families from Carl Studniczka's herbarium","2022","2022-01-11","48","1","89","97","In the C. Studniczka's herbarium we have found...","PDF","acme@acme.hr","AHB_48-6.pdf","Studniczka's herbarium, Natural History Museum Split, Croatia","Mitić, B., Vladović, D., Ževrnja, N. & Anterić, P. (2008) Hladnikia, Ljubljana, 22, 61.","","","","Acta Hor...",""
```

The data is not complete, and many fields have been truncated for brevity. I have used Miller to double quote all the fields in the original data as so: `mlr --csv --quote-all -N unsparsify 2022-preluare-date-v1.csv > 2022-preluare-date-v1-quoted-slim-set-anonimus.csv`. The sample is the result I have obtained. The outcoming CSV should have the following header as mentioned in the README from https://github.com/ualbertalib/ojsxml:

```csv
firstname,lastname,email,affiliation,country,username,tempPassword,role1,role2,role3,role4,reviewInterests
```

I came with the following gawk script after installing gawk 5.3.1 version that is capable of processing CSV nativelly with ease. And here came the banger. The mighty `gawk` doesn't have an easy way to transform UTF-8 characters into ASCII. I needed this in order to generate a viable and accepted username from the `firstName,lastName` as in `Ioana Marcela,Padure` as seen in the first record of the sample file. So, I had to emply the services of `iconv` shell command. And this got me in a swirl for almost a week reading and experimenting with `getline`. I may call this time the pains of learning the specializations of a function when learning a new language. Of course, being stressed and under pressure to solve the issue :)).
To generate a viable password I have found a little magic sript put on the Github for stressed people like myself. Found at the https://github.com/gmesser/make_password.
So, the final script is as the following lines:

```awk
@include "./make_password"
BEGIN {
    print "\"firstname\",\"lastname\",\"email\",\"affiliation\",\"country\",\"tempPassword\",\"role1\",\"username\"";
}
NR > 1 {
    split($4, arr_names, ";");
    split($5, arr_affil, ";");
    if ($16.length > 0 ) 
        first_auth[1]=$16; # it's the email of the first author

    for (i in arr_names) {
        split(arr_names[i], n_p_arr, ",");
        linex = sprintf("\"%s\",\"%s\",\"%s\",\"%s\",\"%s\",\"%s\",\"%s\"",  n_p_arr[1], n_p_arr[2], first_auth[i], arr_affil[i], "", generate_password(10), "Author");       
        firstname = tolower(n_p_arr[1]);
        lastname = tolower(n_p_arr[2]);
        both_strs = firstname"_"lastname; # the addopted schema is firstname_lastname
        gsub(/-/, "_", both_strs); # if you find a - 
        gsub(/ +/, "_", both_strs); # if you find a space
        printf("%s,%s", linex, username); # here is the spot I do not get into my thick head
        # Why is returnig this string after the first run. Looks cryptic to me: `sh: 1: 0: not found`.
        cmd = "iconv --verbose -f utf-8 -t ascii//TRANSLIT";
        system("echo \""both_strs"\" | "cmd) | getline username;
        # while ( (("echo \""both_strs"\" | "cmd) | getline username) > 0) {
        #     print username;
        # }
        close(cmd);
    }
}
```

After the running of the script, I have obtained the following result.

```csv
"firstname","lastname","email","affiliation","country","tempPassword","role1","username"
"Ioana Marcela","Padure","acme@yahoo.com","Universalmuseum Joanneum","","u/Yr7XiE43","Author",ioana_marcela_padure
"Sanja","Simic","","Graz Centre for Electron Microscopy (ZFE)","","Tua-93AE2n","Author",sanja_simic
"Petronela","Camen-Comănescu","pet.acme@acme.ro","University of...","","x4G63w/PmX","Author",petronela_camen_comanescu
"Petronela","Camen-Comănescu","pet.acme@acme.ro","University of..., Botanic Garden","","3x7v9+nPUY","Author",petronela_camen_comanescu
"Daniela Clara","Mihai","","University of..., Faculty of Biology","","cQz9*W8v7G","Author",daniela_clara_mihai
"Dalibor","Vladorić","acme@acme.hr","Natural History Museum and Zoo","","S9BgX78av/","Author",dalibor_vladoric
"Diana","Vlahović","","Primary School Bogumila Tonija","","V2JubD=73d","Author",diana_vlahovic
"Božena","Mitić","","Botanic Institute of PMF University of...","","rke34H9W_A","Author",bozena_mitic
```

The problem is that I had to modify the order of the fields to accomodate the behavior of `getline` function. That is the reason the `username` field was left as the last one. The thing is I write the line here `printf("%s,%s", linex, username)`, the variable `username` is empty and receives the value by the time `getline` is evaluated. But, by that time the control of the program would have being moved already past this line. On short, I try to interpolate the variable in other position than the last, it would spawn an empty field followed by the value or a new line with only the value after the line of the future CSV.

Is there a more elegant way to do it with regards to conversion from UTF-8 to ASCII? That would make `getline` dissapear.

## Ultima versiune

Aceasta este varianta de lucru a scriptului.

```awk
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
```

Comanda de lucru este: `gawk -k -f userextractor.awk 2022-preluare-date-v1-quoted.csv > refined.csv`.


