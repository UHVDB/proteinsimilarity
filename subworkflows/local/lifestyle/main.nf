/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT PLUGINS/FUNCTIONS/MODULES/SUBWORKFLOWS/WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
// MODULES
include { BACPHLIP          } from '../../../modules/local/bacphlip'
include { UHVDB_CATHEADER   } from '../../../modules/local/uhvdb/catheader'

workflow LIFESTYLE {

    take:
    split_virus_fna_gz // channel: [ [ meta ], virus.fna.gz ]

    main:

    //-------------------------------------------
    // MODULE: BACPHLIP
    // inputs:
    // - [ [ meta ], virus.split.fna.gz ]
    // outputs:
    // - [ [ meta ], bacphlip.tsv.gz ]
    // steps:
    // - Gunzip virus fna (script)
    // - Run BACPHLIP (script)
    // - Compress outputs (script)
    // - Cleanup (script)
    //--------------------------------------------
    BACPHLIP(
        split_virus_fna_gz
    )

    //-------------------------------------------
    // MODULE: UHVDB_CATHEADER
    // inputs:
    // - [ [ meta ], [ bacphlip.part_0*.tsv.gz ... ] ]
    // outputs:
    // - [ [ meta ], bacphlip.tsv.gz ]
    // steps:
    // - Print header line (script)
    // - Print non-header lines (script)
    // - Compress (script)
    //--------------------------------------------
    ch_catheader_input = BACPHLIP.out.tsv_gz
        .map { _meta, tsv_gz -> tsv_gz }
        .collect()
        .map { tsv_gz -> [ [ id:'bacphlip' ], tsv_gz, 1, 'tsv' ] }
    UHVDB_CATHEADER(
        ch_catheader_input,
        "${params.output_dir}/annotate/function"
    )

    emit:
    lifestyle_tsv_gz = UHVDB_CATHEADER.out.combined
}

