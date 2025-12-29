/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT PLUGINS/FUNCTIONS/MODULES/SUBWORKFLOWS/WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { CRISPRHOST        } from '../../../subworkflows/local/crisprhost'
include { FUNCTION          } from '../../../subworkflows/local/function'
include { PROTEINSIMILARITY } from '../../../subworkflows/local/proteinsimilarity'
include { PHIST             } from '../../../subworkflows/local/phist'

workflow ANNOTATE {

    take:
    hq_virus_fna_gz         // channel: [ [ meta ], hq_viruses.fna.gz ]
    virus_summary_tsv_gz    // channel: [ [ meta ], genomad_virus_summary.tsv.gz ]

    main:

    //-------------------------------------------
    // SUBWORKFLOW: CRISPRHOST
    // inputs:
    // - [ [ meta ], hq_virus.fna.gz ]
    // outputs:
    // - [ [ meta ], crisprhost.tsv.gz ]
    // steps:
    // - SEQKIT_SPLIT2 (module)
    // - SPACEREXTRACTOR_CREATETARGETDB (module)
    // - SPACEREXTRACTOR_MAPTOTARGET (module)
    // - SPACEREXTRACTOR_COMBINERESULTS (module)
    //--------------------------------------------
    // if ( params.run_crisprhost ) {
    //     CRISPRHOST(
    //         hq_virus_fna_gz
    //     )
    //     ch_crisprhost_tsv_gz = CRISPRHOST.out.crisprhost_tsv_gz
    // } else {
    //     ch_crisprhost_tsv_gz = channel.empty()
    // }

    //-------------------------------------------
    // SUBWORKFLOW: PHIST
    // inputs:
    // - [ [ meta ], hq_virus.fna.gz ]
    // outputs:
    // - [ [ meta ], crisprhost.tsv.gz ]
    // steps:
    // - SEQKIT_SPLIT2 (module)
    // - SPACEREXTRACTOR_CREATETARGETDB (module)
    // - SPACEREXTRACTOR_MAPTOTARGET (module)
    // - SPACEREXTRACTOR_COMBINERESULTS (module)
    //--------------------------------------------
    // if ( params.run_phist ) {
    //     PHIST(
    //         hq_virus_fna_gz
    //     )
    //     ch_phist_csv_gz = PHIST.out.phist_csv_gz
    // } else {
    //     ch_phist_csv_gz = channel.empty()
    // }

    // //
    // // SUBWORKFLOW: Identify most similar reference virus
    // //
    // if ( params.run_proteinsimilarity ) {
    //     PROTEINSIMILARITY(
    //         hq_virus_fna_gz
    //     )
    //     ch_proteinsimilarity_tsv_gz = PROTEINSIMILARITY.out.proteinsimilarity_tsv_gz
    // } else {
    //     ch_proteinsimilarity_tsv_gz = channel.empty()
    // }

    //
    // SUBWORKFLOW: Functionally annotate virus sequences
    //
    if ( params.run_function ) {
        FUNCTION(
            hq_virus_fna_gz,
            virus_summary_tsv_gz
        )
    } else {
        ch_proteinsimilarity_tsv_gz = channel.empty()
    }

    //
    // SUBWORKFLOW: Assign virus lifestyle
    //

}
