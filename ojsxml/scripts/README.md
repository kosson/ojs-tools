# Prelucrarea unui numar de la CSV, la XML

Pentru a rula scriptul ai nevoie ca toate resursele să fie pregătite.
Acest lucru înseamnă că în subdirectorul numărului de revistă ai următoarele resure:
- fișierul CSV cu datele culese corect;
- fișiere PDF, câte unul pentru fiecare articol care va fi procesat;
- fișiere JPG, care reprezintă prima pagină a fiecărui articol.

## Setează .env

```txt
BASE_PATH="/home/kosson/Downloads/PLATFORMA.EDITORIALA/DATE"
USERNAME="master"
```

## Lansează în execuție extract_cover.sh

Acest script este necesar pentru a extrage copertele, adică prima pagină a fiecărui PDF în format jpg.

## Lansarea în execuție

Când scriptul este lansat în execuție, va cere calea absolută a subdirectorului în care se află resursele mai sus amintite.
