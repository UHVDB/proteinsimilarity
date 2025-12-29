/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT PLUGINS/FUNCTIONS/MODULES/SUBWORKFLOWS/WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { ASSEMBLYANALYZE   } from '../../../subworkflows/local/assemblyanalyze'
include { REFERENCEANALYZE  } from '../../../subworkflows/local/referenceanalyze'

//
// Run workflow
//
workflow ANALYZE {

    take:
    hq_virus_fna_gz // channel: [ [ meta ], fna.gz ]

    main:

    // reference-based analysis

    // assembly-based analysis

}
