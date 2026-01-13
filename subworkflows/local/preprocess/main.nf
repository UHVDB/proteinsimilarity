/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT PLUGINS/FUNCITONS/MODULES/SUBWORKFLOWS/WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
// MODULES
include { DEACON_INDEXFETCH } from '../../../modules/local/deacon/indexfetch'
include { READ_DOWNLOAD     } from '../../../modules/local/read/download'
include { READ_PREPROCESS   } from '../../../modules/local/read/preprocess'

workflow PREPROCESS {
    take:
    input_fastqs    // channel: [ [ meta ], [ read1.fastq.gz, read1.fastq.gz? ] ]
    input_sras      // channel: [ [ meta ], sra ]

    main:
    def ch_preprocessed_spring = channel.empty()

    //-------------------------------------------
    // MODULE: DEACON_INDEXFETCH
    // outputs:
    // - index
    // steps:
    // - download deacon index (script)
    //-------------------------------------------
    DEACON_INDEXFETCH()

    //-------------------------------------------
    // MODULE: READ_DOWNLOAD
    // inputs:
    // - [ [ meta ], acc ]
    // - index
    // outputs:
    // - [ [ meta ], spring ]
    // - [ [ meta ], [ read1, read2? ] ]
    // steps:
    // - download fastq with xsra (script)
    // - preprocess with fastp (script)
    // - human removal with deacon (script)
    // - compress with spring (script)
    //-------------------------------------------
    READ_DOWNLOAD(
        input_sras,
        DEACON_INDEXFETCH.out.index.collect()
    )
    ch_preprocessed_spring = READ_DOWNLOAD.out.spring
        .combine(READ_DOWNLOAD.out.pe_count, by:0)
        .map { meta, spring, pe_count ->
            meta.single_end = (pe_count == 1)
            return [ meta, spring ]
        }
        .mix(ch_preprocessed_spring)

    //-------------------------------------------
    // MODULE: READ_PREPROCESS
    // inputs:
    // - [ [ meta ], [ read1.fastq.gz, read1.fastq.gz? ] ]
    // - index
    // outputs:
    // - [ [ meta ], spring ]
    // steps:
    // - preprocess with fastp (script)
    // - human removal with deacon (script)
    // - compress with spring (script)
    //-------------------------------------------
    READ_PREPROCESS(
        input_fastqs,
        DEACON_INDEXFETCH.out.index.collect()
    )
    ch_preprocessed_spring = ch_preprocessed_spring
        .mix(READ_PREPROCESS.out.spring)

    emit:
    preprocessed_spring = ch_preprocessed_spring
}
