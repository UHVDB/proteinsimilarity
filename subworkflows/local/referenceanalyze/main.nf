/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT PLUGINS/FUNCITONS/MODULES/SUBWORKFLOWS/WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// MODULES
include { COVERM_CONTIG     } from '../../../modules/local/coverm/contig'
include { INSTRAIN_COMPARE  } from '../../../modules/local/instrain/compare'
include { INSTRAIN_PROFILE  } from '../../../modules/local/instrain/profile'
include { SYLPH_PROFILE     } from '../../../modules/local/sylph/profile'
include { SYLPH_SKETCH      } from '../../../modules/local/sylph/sketch'

//
// SUBWORKFLOW: Run reference-based analysis
//
workflow REFERENCEANALYZE {

    take:
    ch_preprocessed_spring  // channel: [ [ meta ], reads.spring ]
    hq_virus_fna_gz         // channel: [ [ meta ], fna.gz ]
    hq_virus_gbk_gz         // channel: [ [ meta ], gbk.gz ]

    main:

    // create channel from bacterial sylph sketch
    ch_bac_syldb  = channel.fromPath("${params.bacterial_sylph_db}")

    //
    // MODULE: Create sylph sketch from UHVDB species representatives
    //
    SYLPH_SKETCH(
        hq_virus_fna_gz
    )

    //
    // MODULE: Identify contained genomes with sylph
    //
    SYLPH_PROFILE(
        ch_preprocessed_spring,
        SYLPH_SKETCH.out.syldb,
        ch_bac_syldb
    )

    //
    // MODULE: Align reads to contained genomes
    //
    COVERM_CONTIG(
        ch_preprocessed_spring.combine(SYLPH_PROFILE.out.tsv_gz, by:0),
        hq_virus_fna_gz
    )

    //
    // MODULE: Evaluate microdiversity
    //
    INSTRAIN_PROFILE(
        COVERM_CONTIG.out.bam,
        hq_virus_fna_gz,
        hq_virus_gbk_gz
    )

    // //
    // // MODULE: Assign activity score to each reference genome
    // //
    // ACTIVITYSCORE_REFERENCE(
    //     COVERM_CONTIG.out.tsv_gz.combine(INSTRAIN_PROFILE.out.profile, by:0)
    // )

    //
    // MODULE: Compare microdiversity between samples
    //

    // emit:
    // activity_score_tsv       = UHVDB_ACTIVITYSCORE.out.tsv (for assembly-based analysis)
}
