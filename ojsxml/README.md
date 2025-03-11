# CSV to OJS XML Import for OJS 3.4.0

This collection of scripts and workflow was adapted from https://github.com/rkbuoe/ojsxml repo, which, in turn is a fork of the original repo from https://github.com/ualbertalib/ojsxml.

This application will convert a CSV file into the OJS XML native import file. Following this guide you will be able to use *Native XML Plugin* to upload whole issues, if desired, or use the CLI import scripts.
The XSD is included with this project in the `docroot/output` directory.
Sample CSV files for both users and issues are included in the `examples` directory.

Note: This is NOT a comprehensive CSV to OJS XML conversion, and many fields are left out.

It must be mentioned, that the script needs the following packages to be installed so that SQLite3 is available, and the specific error is silenced.

```bash
sudo apt install sqlite3 php-sqlite3 
```

It would be very useful to be mentioned that a prior check with `php -m` for the `xmlwriter` would eliminate the specific error concerning the module.
If it is not installed, one should do the following on Ubuntu 24.04:

```bash
sudo apt install php8.3-mbstring php8.3-bcmath php8.3-zip php8.3-gd php8.3-curl php8.3-xml php-cli unzip -y.
```

## Known Issues

* Each issue export XML file can contain __only one issue__. The adaptation of the scripts target 3.4. Multiple issues/XML file can lead to database corruption.
* The journal's current issue must be manually set upon import completion. This conversion tool does not indicate which issue should be the current one.
* In the case of the users, the `user_groups` section of the XML must be manually added and is journal specific. This can be found at the top of a User export XML from the current journal (see below for example).
* CSV files should be UTF8 encoded or non-ASCII characters will not appear correctly.

## How to Use

From the CLI `--help` command:

```bash
Script to convert issue or user CSV data to OJS XML.
Usage: issues|users|users:test <ojs_username> <source_directory> <destination_directory>
NB: issues source directory must include "issue_cover_images" and "article_galleys" directory
user:test appends "test" to user email addresses
```

Example:

```bash
php csvToXmlConverter issues username ./input_directory ./output_directory
```

### Issue CSVs

#### Description

The CSV should contain the following headings:

```csv
issueTitle,sectionTitle,sectionAbbrev,authors,affiliation,DOI,articleTitle,year,datePublished,volume,issue,startPage,endPage,articleAbstract,galleyLabel,authorEmail,fileName,keywords,citations,cover_image_filename,cover_image_alt_text,licenseUrl,copyrightHolder,copyrightYear,locale_2,issueTitle_2,sectionTitle_2,articleTitle_2,articleAbstract_2
```

You can have multiple authors in the "authors" field by separating them with a semi-colon. Also, use a comma to separating first and last names.

Example: `Smith, John;Johnson, Jane ...`.

The same rules for authors also apply to affiliation. Separate different affiliations with a semi-colon.
If there is only 1 affiliation and multiple authors that 1 affiliation will be applied to all authors.

Citations can be separated with a new line.

The following fields are optional and can be left empty:

```csv
DOI, volume, issue, subtitle, keywords, citations, affiliation, cover image (both cover_image_filename and cover_image_alt_text must be included or omitted),licenseUrl,copyrightHolder,copyrightYear,locale_2,issueTitle_2,sectionTitle_2,articleTitle_2,articleAbstract_2
```

In May, 2024 some fields were added for basic multilingual support. The extra fields are: `locale_2,issueTitle_2,sectionTitle_2,articleTitle_2,articleAbstract_2`.
The field `locale_2` should use the same format (i.e. `fr_CA`) that OJS uses for it's `locale="en"` attribute.

#### Instructions

1. Set up the variables in the `config.ini` file. See Annex 1 for an example.
2. Place CSV file(s) in a single directory (optionally `docroot/csv/abstracts`, which has already been created):
   * The `abstracts` input directory must contain an `article_galleys` and `issue_cover_images` directory (both of which exist within `docroot/csv/abstracts`),
   * You can place multiple CSV files in the directory however do not split a single issue across multiple CSV files, but you can have multiple issues in a single CSV file.
3. Place all PDF galleys in the `article_galleys` directory.
4. If you have cover images place them in the `issue_cover_images` directory.
4. Run `php csvToXmlConverter.php issues ojs_username ./docroot/csv/abstracts ./docroot/output`.
5. The XML file(s) will be output in the specified output directory (`docroot/output` directory in this case).

You may copy by hand all the resources in their indicated places, but if you have structured a subdirectory with all the article PDFs and the CSV file, you may use the `process-issue.sh` Bash script that will do all the heavy lifting for you:
- copying the PDFs to the `article_galleys` directory;
- extracting the first page of each PDF file as cover image and place it to the `issue_cover_images` directory;
- copying the CSV file in the `/docroot/csv/abstracts` subdirectory, and;
- running the php command that will create the XML file in the `docroot/output` directory.

At the moment of running the command, the process will ask you to give it the full path (not the relative) of the directory whre the CSV and the PDFs are located. After you give the correct path, the magic will happen.

Before using this script, rename the `dot.env` file to `.env`, open it and modify the `BASE_PATH` value according to your environment.

### User CSVs

#### Description

The CSV must be in the format of: `firstname,lastname,email,affiliation,country,username,tempPassword,role1,role2,role3,role4,reviewInterests`.

Review interests should be separated by a comma.
Example: `interest one, interest two ...`.

The following fields are optional and can be left empty: `lastname, affiliation, country, password, role1, role2, role3, role4, reviewInterests`.

NB: If a temporary password is not supplied, a new password will be created and the user will be notified by email.

#### Instructions

1. Set up the variables in the `config.ini` file.
2. Place CSV file(s) in a single directory (optionally `docroot/csv/users`)
3. Run `php csvToXmlConverter.php users ojs_username ./docroot/csv/users ./docroot/output`
4. The XML file(s) will be output in the specified output directory (`docroot/output` directory in this case)
5. Add the `user_groups` section from a User export from the journal to the newly created XML file(s).

The `user_groups` section of the XML is specific to each journal and should therefore be taken from a sample user export from the intended journal. Any role added in the import CSV must match the `name` tag for the given user group or it will default to `Reader`.

Current valid roles include:

- Journal manager
- Section editor
- Reviewer
- Author
- Reader

The user export XML should be in the following format:

```xml
<?xml version="1.0"?>
<PKPUsers xmlns="http://pkp.sfu.ca" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xsi:schemaLocation="http://pkp.sfu.ca pkp-users.xsd">
  <user_groups xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
               xsi:schemaLocation="http://pkp.sfu.ca pkp-users.xsd">
    [... add journal specific user groups here]
  </user_groups>
  <users>
    [...generated by conversion tool]
  </users>
</PKPUsers>
```

At least one `user_group` must be included inside the `user_groups` tag. The `user_group` XML will look something like this:

```xml
<user_group>
  <role_id>1048576</role_id>
  <context_id>1</context_id>
  <is_default>true</is_default>
  <show_title>false</show_title>
  <permit_self_registration>true</permit_self_registration>
  <permit_metadata_edit>false</permit_metadata_edit>
  <name locale="en_US">Reader</name>
  <abbrev locale="en_US">Read</abbrev>
  <stage_assignments/>
</user_group>
```

## Hack your way to do the import

First, upload the users of the issue you want to upload. You'll need it latter to assign as primary contacts. The best practice would be to have all the authors as users in a curated XML file already imported. Make sure your application uses workers. In large numbers, the uploads will be done partially. For example, from two hundred users, only a few dozens will be imported... mind this gap. For safety, use workers administrated by Supervisor. See the official documentation. Check the

```bash
sudo nano php/8.2/fpm/php.ini
```

for the following:

```txt
post_max_size = 200M
upload_max_filesize = 200M
max_file_uploads = 100
error_log = php_errors.log
```

The increased values for RAM will avoid bamboozeled frustrated red face.
Remember to restart the PHP service after doing the modifications:

```bash
sudo systemctl restart php8.2-fpm
```

If you application is managed via Supervisor, you may restart the service with the following command:

```bash
sudo supervisorctl restart all
```

### Avoid $setsequence wrong type

Unfortunatelly the application is not ready for the import of the XML file as is. It needs a bit of tinkering first as folows.
Lines 340 and 377 of the original file `NativeXmlIssueFilter.php` must be modified prior any attempt of upload.

Edit the file:

```bash
sudo nano -l /var/www/<name.ofthe.journal.io>/plugins/importexport/native/filter/NativeXmlIssueFilter.php
```

where `<name.ofthe.journal.io>` is the name of the journal you are working on. This is necessary to avoid the following error:

```txt
## Errors occured:
Generic Items
- PKP\section\PKPSection::setSequence(): Argument #1 ($sequence) must be of type float, string given, called in /var/www/revue.of.lis/plugins/importexport/native/filter/NativeXmlIssueFilter.php on line 340
```

Edit the fragment `$section->setSequence($node->getAttribute('seq'));` on the line 340, and modify it as follows:

```php
$section->setSequence(floatval($node->getAttribute('seq')));
```

Function `floatval` wrapping will ensure correct casting.
Edit the line 347, and modify it as follows:

```php
$section->setAbstractWordCount(floatval($node->getAttribute('abstract_word_count')));
```

to avoid the following error:

```txt
APP\section\Section::setAbstractWordCount(): Argument #1 ($wordCount) must be of type int, string given, called in /var/www/<name.ofthe.journal.io>/plugins/importexport/native/filter/NativeXmlIssueFilter.php on line 347
```

Now you are ready to make the next step which involves modifications to the database, unfortunatelly. No biggie, though.

### The integrity constraint violation

You are not out of the woods, yet.
Making an attempt to upload the file to import it, it will throw an error generated by the database this time. The entire error message is something along the following lines:

```txt
SQLSTATE[23000]: Integrity constraint violation: 1452 Cannot add or update a child row: a foreign key constraint fails 

(`journalsunibuc`.`publications`, 
	CONSTRAINT `publications_primary_contact_id` 
	FOREIGN KEY (`primary_contact_id`) 
	REFERENCES `authors` (`author_id`) 
	ON DELETE SET NULL
	) 
 
(SQL: update `publications` set `access_status` = 0, `date_published` = 2022-09-16, `last_modified` = 2025-01-25 19:24:02, `primary_contact_id` = 0, `section_id` = 2, `seq` = 0, `submission_id` = 380, `status` = 3, `url_path` = ?, `version` = 1, `doi_id` = ? where `publication_id` = 380)
```

This one is tricky because you have to delete the constraint between the `publications` table, and the `authors` table. This is not reflected in the base code, and causes issues on upload.

![](doc/img/FK-publications_primary_contact_id.png)

Then you need to destroy the foreign key connection from the `authors` table as well. If you do not operate these modifications, you cannot make the import in OJS 3.4.0.8 version, at least.
For making the modifications, [DBeaver Community](https://dbeaver.io/) was used being configured to access the database via ssh. Do not edit the database without a backup first. The modifications were applied to a virtualized copy of the OJS multijournal application.

Delete the `publications_primary_contact_id` from `Foreign keys` belonging to the `publications` table.
Delete the `authors_publication_id_foreign` from `Foreign keys` belonging to the `authors` table.  In a simple SQL script, the following commands are enough.

```sql
ALTER TABLE `authors` DROP FOREIGN KEY `authors_publications_id_foreign`;
ALTER TABLE `publications` DROP FOREIGN KEY `publications_primary_contact_id`;
```

### Upload using the CLI tools

First, initiate a Terminal session, and go to the root directory of the app. Now, as a measure of safety, check what plugins are available running the following command:

```bash
php tools/importExport.php list
```

The result looks like the following answer:

```txt
Available plugins:
	NativeImportExportPlugin
	UserImportExportPlugin
	DOAJExportPlugin
	QuickSubmitPlugin
	PubMedExportPlugin
```

To get some documentation on the CLI tool needed available run the following command:

```bash
sudo php tools/importExport.php NativeImportExportPlugin usage
```

with the following results returned:

```txt
Usage: tools/importExport.php NativeImportExportPlugin [command] ...
Commands:
	import [xmlFileName] [journal_path] [--user_name] ...
	export [xmlFileName] [journal_path] articles [articleId1] [articleId2] ...
	export [xmlFileName] [journal_path] article [articleId]
	export [xmlFileName] [journal_path] issues [issueId1] [issueId2] ...
	export [xmlFileName] [journal_path] issue [issueId]

Additional parameters are required for importing data as follows, depending
on the root node of the XML document.

If the root node is <article> or <articles>, additional parameters are required.
The following formats are accepted:

tools/importExport.php NativeImportExportPlugin import [xmlFileName] [journal_path] [--user_name]
	issue_id [issueId] section_id [sectionId]

tools/importExport.php NativeImportExportPlugin import [xmlFileName] [journal_path] [--user_name]
	issue_id [issueId] section_name [name]

tools/importExport.php NativeImportExportPlugin import [xmlFileName] [journal_path]
	issue_id [issueId] section_abbrev [abbrev]
```

Now you are in business. Proced to the PHP command.

#### Do the import

Now you are free to upload and import the XML issue file you have created. For the big file uploads (base64 encoding of "heavy" PDFs) do not use the GUI. Resource to the script available in the `tools` subdirectory of the original OJS application.
Let's get grinding. Position yourself in the root of the application, and issue the following command in the terminal:

```bash
sudo php tools/importExport.php NativeImportExportPlugin import issues_0.xml ahbb --user_name master
```

where `issues_0.xml` is the file you have obtained running the *ojsxml* application, and `ahbb` being the stub by which the journal is known.

If all goes well, the following look-like positive response should be returned at the end of a big scroll of DB operation:

```txt
The import completed successfully. The following items were imported:

Submission
-"394" - "Sem studies regarding micromorphology of fruit"
-"395" - "First record of snowfall after over 25 years"
-"396" - "Alien flora from Neverland"
-"397" - "Contributions to the identification wild dreams"
-"398" - "Contributions to the study of alien invasive species in local pubs"
-"399" - "Analysis of some families from pilgrim's herbarium"
Issue
-"68" - "Vol. 48 No. 1 (2022): Acta Quietem Machinarium"
```

Now, what you need to do is to go to GUI, and for each article of the newly imported issue, unpublish it, go to the `Contributors`, and `Set primary contact`. This will create the necessary links in the database. See below with only the first article set how it looks like.

![](doc/img/Linkage-onearticle.png)

And for all the articles in the issue:

![](doc/img/Linkage-all_articles_of_issue.png).

Observe how `primary_contact_id` column gets populated with the correspondent values.
All this implies a downtime needed of the app for safety reasons. You may try it on the fly on the production machine, but I would strongly not advice such move. Better safe than sorry.

After you finished your import, redo all the links you've just destroyed. A simple SQL script as following.

```sql
ALTER TABLE journalsunibuc.authors ADD CONSTRAINT authors_publications_id_foreign FOREIGN KEY (publication_id) REFERENCES journalsunibuc.publications(publication_id) ON DELETE CASCADE ON UPDATE RESTRICT;
ALTER TABLE journalsunibuc.publications ADD CONSTRAINT publications_primary_contact_id FOREIGN KEY (primary_contact_id) REFERENCES journalsunibuc.authors(author_id) ON DELETE SET NULL ON UPDATE RESTRICT;
```

You could redo the connections manualy, but after doing this for a few rounds, it gets tedious.

Provided all went well, you have successfuly imported a whole issue.

## Annex 1

Example of working `config.ini`.

```txt
[General]
; Used to support MySQL however these database tended to be small so SQLite is all that is needed.
db_type = SQLite
sqlite_location = mysqlitedb.db
temp_table_name = ojs_import_helper

; DO NOT CHANGE
; NB: Current limitation for OJS 3.2. Maximum of one issue per file for import xml.
issues_per_file = 1

; URL where PDFs are located
; NB: Not used with OJS 3.2 conversion
pdf_url = http://127.0.0.1/

; Required fields for OJS. To be applied across all conversions
author_country = ""

;locale = "en_US"
;For OJS 3.4 you must set this to just 'en'
locale = "en"

; For use when formatting dates via DateTime::createFromFormat()
dateFormat = "Y-m-d"

; Needed for use with custom genre, e.g. "Manuscript"
genreName = ""

; Outputs info written to console to a file for reference
logLocation = "/tmp"

;Set wether we're doing a back issues import
;Applies to 3.4 only - we want everything under the default author id to avoid database integrity constraint violation
isBackIssues = False

; Default author id
; For a back issues import, choose the id of an existing author, such as an editor
defaultAuthorId = 0

; Set whether destination OJS is version 3.4
is34 = True

; To get this to work on 3.4, a couple of hacky modifications to:
; plugins/importexport/native/filter/NativeXmlIssueFilter.php
; on lines 340 and 347 are required (casts to float and int respectively)
```

## Modifications

19 Feb, 2025

- ojsxml code was refactored to use Composer. Now you may launch the command from anywhere you like (as part of scripts)
- `process-issue.sh` Bash script will do all the heavy lifting for you, and skip all the boring steps. See in documentation above

11 Mar, 2025

- ojsxml README has been completed with the necessary steps to be taken in order to import the XML file in OJS.