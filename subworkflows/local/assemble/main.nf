/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT PLUGINS/FUNCTIONS/MODULES/SUBWORKFLOWS/WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
// MODULES
include { SPRING_CAT    } from '../../../modules/local/spring/cat'
include { MEGAHIT       } from '../../../modules/local/megahit'

workflow ASSEMBLE {

    take:
    reads_spring    // channel: [ [ meta ], reads.spring ]

    main:

    if ( params.run_coassembly ) {
        // group and set group as new id
        ch_coassembly_spring = reads_spring
            .map { meta, spring ->
                def grouping        = [:]
                grouping.group      = meta.coassembly_group
                grouping.single_end = meta.single_end
                grouping.from_sra   = meta.from_sra

                [ grouping, meta, spring ]
            }
            .groupTuple( by: 0, sort:'deep' )
            .map { grouping, meta, spring ->
                def meta_new                = [:]
                meta_new.id                 = "${grouping.group}_coassembly".toString()
                meta_new.bioproject          = meta.source_db[0]
                meta_new.group              = grouping.group
                meta_new.single_end         = grouping.single_end
                meta_new.from_sra           = grouping.from_sra
                return [ meta_new, spring.flatten() ]
            }

        //-------------------------------------------
        // MODULE: SPRING_CAT
        // inputs:
        // - [ [ meta ], [ *_coassembly.spring ... ] ]
        // outputs:
        // - [ [ meta ], grouped.spring ]
        // steps:
        // - Extract spring archive (script)
        // - Concatenate fastqs (script)
        // - Convert to spring (script)
        // - Cleanup (script)
        //--------------------------------------------
        SPRING_CAT(
            ch_coassembly_spring
        )
        ch_reads_spring = reads_spring.mix(SPRING_CAT.out.spring)
    }

    //
    // MODULE: Assemble reads with MEGAHIT
    //
    MEGAHIT(
        ch_reads_spring
    )

    emit:
    reads_spring        = ch_reads_spring
    assembly_fna_gz     = MEGAHIT.out.fna_gz
}

