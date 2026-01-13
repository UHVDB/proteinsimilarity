/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT PLUGINS/FUNCTIONS/MODULES/SUBWORKFLOWS/WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
// MODULES
include { SEQKIT_SPLIT2         } from '../../../modules/local/seqkit/split2'

// SUBWORKFLOWS
include { CRISPRHOST            } from '../../../subworkflows/local/crisprhost'
include { FUNCTION              } from '../../../subworkflows/local/function'
include { LIFESTYLE             } from '../../../subworkflows/local/lifestyle'
include { PHIST                 } from '../../../subworkflows/local/phist'
include { PROTEINSIMILARITY     } from '../../../subworkflows/local/proteinsimilarity'

workflow ANNOTATE {

    take:
    unique_virus_fna_gz     // channel: [ [ meta ], unique_virus.fna.gz ]
    split_virus_fna_gz      // channel: [ [ meta ], unique_virus.part_*.fna.gz ]
    virus_summary_tsv_gz    // channel: [ [ meta ], unique_virus_summary.tsv.gz ]

    main:

    //-------------------------------------------
    // SUBWORKFLOW: CRISPRHOST
    // inputs:
    // - [ [ meta ], unique_virus.fna.gz ]
    // outputs:
    // - [ [ meta ], crisprhost.tsv.gz ]
    // steps:
    // - SEQKIT_SPLIT2 (module)
    // - SPACEREXTRACTOR_CREATETARGETDB (module)
    // - SPACEREXTRACTOR_MAPTOTARGET (module)
    // - SPACEREXTRACTOR_COMBINERESULTS (module)
    //--------------------------------------------
    if ( params.run_crisprhost ) {
        CRISPRHOST(
            unique_virus_fna_gz
        )
        ch_crisprhost_tsv_gz = CRISPRHOST.out.crisprhost_tsv_gz
    } else {
        ch_crisprhost_tsv_gz = channel.empty()
    }

    //-------------------------------------------
    // SUBWORKFLOW: PHIST
    // inputs:
    // - [ [ meta ], unique_virus.fna.gz ]
    // outputs:
    // - [ [ meta ], crisprhost.tsv.gz ]
    // steps:
    // - SEQKIT_SPLIT2 (module)
    // - SPACEREXTRACTOR_CREATETARGETDB (module)
    // - SPACEREXTRACTOR_MAPTOTARGET (module)
    // - SPACEREXTRACTOR_COMBINERESULTS (module)
    //--------------------------------------------
    if ( params.run_phist ) {
        PHIST(
            unique_virus_fna_gz
        )
        ch_phist_csv_gz = PHIST.out.phist_csv_gz
    } else {
        ch_phist_csv_gz = channel.empty()
    }

    //-------------------------------------------
    // SUBWORKFLOW: TAXONOMY
    // inputs:
    // - [ [ meta ], unique_virus.part_*.fna.gz ]
    // outputs:
    // - [ [ meta ], crisprhost.tsv.gz ]
    // steps:
    // - SEQKIT_SPLIT2 (module)
    //--------------------------------------------
    if ( params.run_proteinsimilarity ) {
        PROTEINSIMILARITY(
            split_virus_fna_gz
        )
        ch_proteinsimilarity_tsv_gz = PROTEINSIMILARITY.out.proteinsimilarity_tsv_gz
    } else {
        ch_proteinsimilarity_tsv_gz = channel.empty()
    }

    //-------------------------------------------
    // SUBWORKFLOW: FUNCTION
    // inputs:
    // - [ [ meta ], unique_virus.part_*.fna.gz ]
    // - [ [ meta ], virus_summary.tsv.gz ]
    // outputs:
    // - [ [ meta ], bakta.gbk.gz ]
    // - [ [ meta ], phrog.tsv.gz ]
    // - [ [ meta ], empathi.tsv.gz ]
    // steps:
    // - BAKTA_DOWNLOAD (module)
    // - BAKTA_GETMOD (module)
    // - DEFENSEFINDER_UPDATE (module)
    // - FOLDSEEK_CREATEDB (module)
    // - INTERPROSCAN_DOWNLOAD (module)
    // - EMPATHI_INSTALL (module)
    // - PADLOC_UPDATE (module)
    // - PHAROKKA_INSTALLDATABASES (module)
    // - PHOLD_INSTALL (module)
    // - PHYNTENYTRANSFORMER_INSTALLMODELS (module)
    // - PSEUDOFINDER_MAKEDB (module)
    // - PSEUDOFINDER_GETMOD (module)
    // - UNIREF50VIRUS (module)
    // - GENETICCODE_SPLIT (module)
    // - SEQKIT_SPLIT2 (module)
    // - BAKTA_VIRUS (module)
    // - INTERPROSCAN_INTERPROSCAN (module)
    // - FOLDSEEK_CREATEDBPROSTT5 (module)
    // - FOLDSEEK_EASYSEARCH (module)
    // - PSEUDOFINDER_ANNOTATE (module)
    // - DEFENSEFINDER_RUN (module)
    // - PADLOC_PADLOC (module)
    // - DGRSCAN (module)
    // - PHAROKKA_PHAROKKA (module)
    // - PHOLD_PREDICT (module)
    // - PHOLD_COMPARE (module)
    // - PHYNTENYTRANSFORMER_PHYNTENYTRANSFORMER (module)
    // - EMPATHI_ONLYEMBEDDINGS (module)
    // - EMPATHI_EMPATHI (module)
    //--------------------------------------------
    if ( params.run_function ) {
        FUNCTION(
            split_virus_fna_gz,
            virus_summary_tsv_gz
        )
        ch_bakta_gbk_gz     = FUNCTION.out.bakta_gbk_gz
        ch_bakta_faa_gz     = FUNCTION.out.bakta_faa_gz
        ch_empathi_csv_gz   = FUNCTION.out.empathi_csv_gz
        ch_phynteny_tsv_gz  = FUNCTION.out.phynteny_tsv_gz
    } else {
        ch_bakta_gbk_gz     = channel.empty()
        ch_bakta_faa_gz     = channel.empty()
        ch_empathi_csv_gz   = channel.empty()
        ch_phynteny_tsv_gz  = channel.empty()
    }

    //-------------------------------------------
    // SUBWORKFLOW: LIFESTYLE
    // inputs:
    // - [ [ meta ], unique_virus.part_*.fna.gz ]
    // outputs:
    // - [ [ meta ], crisprhost.tsv.gz ]
    // steps:
    // - SEQKIT_SPLIT2 (module)
    //--------------------------------------------
    if ( params.run_lifestyle ) {
        LIFESTYLE(
            split_virus_fna_gz
        )
        ch_lifestyle_tsv_gz  = LIFESTYLE.out.lifestyle_tsv_gz
    } else {
        ch_lifestyle_tsv_gz  = channel.empty()
    }

}
