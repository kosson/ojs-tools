<?php
namespace OJSXml;

use Exception;

class TempTable
{
    protected $db;
    protected $tempTableName;

    /**
     * TempTable constructor.
     * @param \App\Database $db
     * @param string $tempTableName
     */
    function __construct(Database $db, $tempTableName='ojs_import_helper')
    {
        $this->db = $db;
        $this->tempTableName=$tempTableName;
        $this->createTable();
    }

    function truncate(){
        $this->db->query("DELETE FROM " . $this->tempTableName);
        $this->db->execute();
    }

    function isEmpty(){
        $row = $this->db->single("Select count(*) as counter from " .$this->tempTableName);
        if($row['counter']>0){
            throw new Exception("Table '" . $this->tempTableName . "' must be blank to start the process");
        }
        return true;
    }

    private function createTable(){
		
		$this->db->query("DROP TABLE IF EXISTS " . $this->tempTableName );
		$this->db->execute();
		
        $sql = "CREATE TABLE IF NOT EXISTS " . $this->tempTableName . " (      
                      `issueTitle` varchar(500)  DEFAULT NULL,
                      `sectionTitle` varchar(500)  DEFAULT NULL,
                      `sectionAbbrev` varchar(500)  DEFAULT NULL,
                      `authors` varchar(500)  DEFAULT NULL, 
                      `affiliations` varchar(500) DEFAULT NULL, 
                      `orcid` varchar (1500) DEFAULT NULL,
                      `DOI` varchar(500) DEFAULT NULL,                       
                      `articleTitle` varchar(500)  DEFAULT NULL, 
                      `subTitle` varchar(500)  DEFAULT NULL, 
                      `year` int(11) DEFAULT NULL,
                      `datePublished` datetime DEFAULT NULL,
                      `volume` int(11) DEFAULT NULL,
                      `issue` int(11) DEFAULT NULL,
                      `startPage` int(11) DEFAULT NULL,
                      `endPage` varchar(50)  DEFAULT NULL,
                      `articleAbstract` varchar(2000)  DEFAULT NULL,
                      `galleyLabel` varchar(500)  DEFAULT NULL,
                      `authorEmail` varchar(500)  DEFAULT NULL,
                      `fileName` varchar(500)  DEFAULT NULL,
                      `supplementary_files` varchar(500)  DEFAULT NULL,                      
                      `dependent_files` varchar(500)  DEFAULT NULL,   
                      `keywords` varchar(500)  DEFAULT NULL,
					  `citations` TEXT  DEFAULT NULL, 
                      `cover_image_filename` varchar(500) DEFAULT NULL,
                      `cover_image_alt_text` varchar(500) DEFAULT NULL,
                      `issue_cover_image_filename` varchar(500) DEFAULT NULL,
                      `issue_cover_image_alt_text` varchar(500) DEFAULT NULL,
                      `language` varchar(10) DEFAULT NULL,
					  `licenseUrl` varchar(500) DEFAULT NULL,
					  `copyrightHolder` varchar(500) DEFAULT NULL,
					  `copyrightYear` varchar(50) DEFAULT NULL,
					  `locale_2` varchar(50) DEFAULT NULL,
					  `issueTitle_2` varchar(500) DEFAULT NULL,
					  `sectionTitle_2` varchar(500) DEFAULT NULL,
					  `articleTitle_2` varchar(500) DEFAULT NULL,
					  `articleAbstract_2` varchar(2000) DEFAULT NULL
                    )";
        $this->db->query($sql);
        $this->db->execute();
    }

    function insertAssocDataIntoTempTable($data){
        $sql = "INSERT into " . $this->tempTableName . "
        (issueTitle,sectionTitle,sectionAbbrev,authors,affiliations,orcid,DOI,articleTitle,subTitle,year,datePublished,volume,issue,startPage,endPage,articleAbstract,galleyLabel,authorEmail,fileName,supplementary_files,dependent_files,keywords,citations,cover_image_filename,cover_image_alt_text,issue_cover_image_filename,issue_cover_image_alt_text,language,licenseUrl,copyrightHolder,copyrightYear,locale_2,issueTitle_2,sectionTitle_2,articleTitle_2,articleAbstract_2) 
        VALUES (:issueTitle,:sectionTitle,:sectionAbbrev,:authors,:affiliations,:orcid,:DOI,:articleTitle,:subTitle,:year,:datePublished,:volume,:issue,:startPage,:endPage, :articleAbstract,:galleyLabel,:authorEmail,:fileName,:supplementary_files,:dependent_files,:keywords,:citations,:cover_image_filename,:cover_image_alt_text,:issue_cover_image_filename,:issue_cover_image_alt_text,:language,:licenseUrl,:copyrightHolder,:copyrightYear,:locale_2,:issueTitle_2,:sectionTitle_2,:articleTitle_2, :articleAbstract_2)";
        $this->db->query($sql);
        $this->db->bind(':issueTitle', empty_string_if_null($data['issueTitle'])); // may exist or not
        $this->db->bind(':sectionTitle', empty_string_if_null($data['sectionTitle'])); // may exist or not
        $this->db->bind(':sectionAbbrev', empty_string_if_null($data['sectionAbbrev'])); // may exist or not
        $this->db->bind(':authors', empty_string_if_null($data['authors']));

        if(isset($data['affiliation']) || isset($data['affiliations'])){
            $this->db->bind(':affiliations', (isset($data['affiliation']) ? $data['affiliation'] : $data['affiliations']));
        } elseif (isset($data['authorAffiliation'])){
            $this->db->bind(':affiliations', $data['authorAffiliation']);
        } else {
            $this->db->bind(':affiliations', '');
        }

        $this->db->bind(':orcid', empty_string_if_null($data['orcid'])); // may have an ORCIDs or not
        $this->db->bind(':DOI', empty_string_if_null($data['DOI']));
        $this->db->bind(':articleTitle', empty_string_if_null($data['articleTitle']));
        $this->db->bind(':subTitle', empty_string_if_null($data['subTitle']));
        $this->db->bind(':year', empty_string_if_null($data['year']));
        $this->db->bind(':datePublished', empty_string_if_null($data['datePublished']));
        $this->db->bind(':volume', empty_string_if_null($data['volume']));
        $this->db->bind(':issue', $data['issue'] ?? $data['Issue'] ?? '');
        $this->db->bind(':startPage', empty_string_if_null($data['startPage']));
        $this->db->bind(':endPage', empty_string_if_null($data['endPage']));

		$articleAbstract = isset($data['articleAbstract']) ? $data['articleAbstract'] : '';
        $this->db->bind(':articleAbstract', $articleAbstract);
        $this->db->bind(':galleyLabel', empty_string_if_null($data['galleyLabel']));
        $this->db->bind(':authorEmail', empty_string_if_null($data['authorEmail']));
        $this->db->bind(':fileName', empty_string_if_null($data['fileName']));
        $this->db->bind(':supplementary_files', empty_string_if_null($data['supplementary_files']));
        $this->db->bind(':dependent_files', empty_string_if_null($data['dependent_files']));     

        $val = "";

        if(key_exists('keywords',$data)){
            $val = $data['keywords'];
        }
        $this->db->bind(':keywords',$val);
		
		$cval = "";

        if(key_exists('citations',$data)){
            $cval = $data['citations'];
        }
        
		$this->db->bind(':citations', $cval);
        $this->db->bind(':cover_image_filename', $data['cover_image_filename'] ?? '');
        $this->db->bind(':cover_image_alt_text', $data['cover_image_alt_text'] ?? '');        
        $this->db->bind(':issue_cover_image_filename', $data['issue_cover_image_filename'] ?? ''); // may exist or not
        $this->db->bind(':issue_cover_image_alt_text', $data['issue_cover_image_alt_text'] ?? '');   
        $this->db->bind(':language', $data['language'] ?? '');
		$this->db->bind(':licenseUrl', $data['licenseUrl'] ?? '');
		$this->db->bind(':copyrightHolder', $data['copyrightHolder'] ?? '');
		$this->db->bind(':copyrightYear', $data['copyrightYear'] ?? '');
		
		/*  Second Locale */
		$this->db->bind(':locale_2', $data['locale_2'] ?? '');        
		$this->db->bind(':issueTitle_2', $data['issueTitle_2'] ?? '');
		$this->db->bind(':sectionTitle_2', $data['sectionTitle_2'] ?? '');		 
        $this->db->bind(':articleTitle_2', $data['articleTitle_2'] ?? '');
		$this->db->bind(':articleAbstract_2', $data['articleAbstract_2'] ?? '');
        
        $this->db->execute();
    }
}
