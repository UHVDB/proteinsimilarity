/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT PLUGINS/FUNCTIONS/MODULES/SUBWORKFLOWS/WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { ASSEMBLE        } from '../../../subworkflows/local/assemble'
include { CLASSIFY        } from '../../../subworkflows/local/classify'

workflow MINE {

    take:
    reads_spring    // channel: [ [ meta ], reads.spring ]
    assembly_fna_gz // channel: [ [ meta ], assembly.fna.gz ]
    virus_fna_gz    // channel: [ [ meta ], virus.fna.gz ]

    main:

    ch_assembly_fna_gz = channel.empty()
    ch_reads_spring    = channel.empty()

    //-------------------------------------------
    // SUBWORKFLOW: ASSEMBLE
    // inputs:
    // - [ [ meta ], reads.spring ]
    // outputs:
    // - [ [ meta ], grouped.spring ]
    // - [ [ meta ], assembly.fna.gz ]
    // steps:
    // - SPRING_CAT (module)
    // - MEGAHIT (module)
    //--------------------------------------------
    if ( params.run_assemble ) {
        ASSEMBLE(
            reads_spring
        )
        ch_assembly_fna_gz = assembly_fna_gz
            .mix(ASSEMBLE.out.assembly_fna_gz)
        ch_reads_spring = ASSEMBLE.out.reads_spring
    }

    //
    // SUBWORKFLOW: Classify viral sequences from an assembly
    //

    //
    // SUBWORKFLOW: Filter HQ and high-confidence viruses
    //

    emit:
    assembly_fna_gz = ch_assembly_fna_gz
    reads_spring    = ch_reads_spring
}
