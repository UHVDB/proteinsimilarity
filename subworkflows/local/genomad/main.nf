/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT PLUGINS/FUNCITONS/MODULES/SUBWORKFLOWS/WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
// MODULES
include { GENOMAD_DOWNLOADDATABASE  } from '../../../modules/local/genomad/downloaddatabase'
include { GENOMAD_ENDTOEND          } from '../../../modules/local/genomad/endtoend'

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
    ch_preprocessed_spring = ch_preprocessed_spring
        .mix(READ_DOWNLOAD.out.spring)

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
