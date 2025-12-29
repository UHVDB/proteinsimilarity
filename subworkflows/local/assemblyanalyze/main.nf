/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT PLUGINS/FUNCITONS/MODULES/SUBWORKFLOWS/WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// MODULES
include { MVIRS             } from '../../../modules/local/mvirs/oprs'
include { PROPAGATE         } from '../../../modules/local/propagate'
include { SPACEREXTRACTOR   } from '../../../modules/local/spacerextractor'

//
// SUBWORKFLOW: Run assembly-based analysis
//
workflow ASSEMBLYANALYZE {

    take:
    ch_preprocessed_spring  // channel: [ [ meta ], reads.spring ]
    assembly_fna_gz         // channel: [ [ meta ], fna.gz ]
    hq_virus_gbk_gz         // channel: [ [ meta ], gbk.gz ]

    main:


    // //
    // // MODULE: Assign activity score to each reference genome
    // //
    // ACTIVITYSCORE_ASSEMBLY(
    //     COVERM_CONTIG.out.tsv_gz.combine(INSTRAIN_PROFILE.out.profile, by:0)
    // )

    // emit:
    // coverm_tsv_gz            = COVERM_CONTIG.out.tsv_gz (for assembly-based analysis)
    // activity_score_tsv       = UHVDB_ACTIVITYSCORE.out.tsv (for assembly-based analysis)
}
