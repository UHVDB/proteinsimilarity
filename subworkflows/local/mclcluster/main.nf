/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT PLUGINS/FUNCTIONS/MODULES/SUBWORKFLOWS/WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
// MODULES
include { UHVDB_PRUNE   } from '../../../modules/local/uhvdb/prune'
include { MCL           } from '../../../modules/local/mcl'

workflow MCLCLUSTER {

    take:
    matrix_tsv_gz           // channel: [ [ meta ], matrix.tsv.gz ]
    mcl_gz                  // channel: [ [ meta ], clusters.mcl.gz ]
    similarity_threshold    // val: float
    publish_dir             // val: string

    main:

    //-------------------------------------------
    // MODULE: UHVDB_PRUNE
    // inputs:
    // - [ [ meta ], matrix.tsv.gz ]
    // - [ [ meta ], clusters.mcl.gz ]
    // - similarity_threshold
    // outputs:
    // - [ [ meta ], matrix.pruned.tsv.gz ]
    // steps:
    // - Prune graph (script)
    // - Compress (script)
    //--------------------------------------------
    UHVDB_PRUNE(
        matrix_tsv_gz,
        mcl_gz,
        similarity_threshold
    )

    //-------------------------------------------
    // MODULE: MCL_MCL
    // inputs:
    // - [ [ meta ], aaicluster.pruned.tsv.gz ]
    // outputs:
    // - [ [ meta ], aaicluster.mcl.gz ]
    // steps:
    // - Decompress (script)
    // - Run MCL (script)
    //--------------------------------------------
    MCL(
        UHVDB_PRUNE.out.tsv_gz,
        publish_dir
    )

    emit:
    mcl_gz = MCL.out.mcl_gz
}
