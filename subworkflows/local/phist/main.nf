/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    phist
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL PLUGINS/FUNCTIONS/MODULES/SUBWORKFLOWS/WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { KMERDB_BUILD  } from '../../../modules/local/kmerdb/build'
include { PHIST_ARIA2C  } from '../../../modules/local/phist/aria2c'
include { PHIST_COMBINE  } from '../../../modules/local/phist/combine'


// Run entry workflow
workflow PHIST {

    take:
    hq_virus_fna_gz // channel: [ [ meta ], fna.gz ]

    main:

    // Split host URLs into chunks
    ch_host_fastas = channel.fromPath(params.host_urls)
        .splitCsv(header: false, strip: true)
        .flatten()
        .collate(params.chunk_size)
        .toList()
        .flatMap{ file -> file.withIndex() }
        .map { file, index ->
            [ [ id: 'chunk_' + index ], file ]
        }

    //
    // MODULE: Create kmer-db database from virus fasta
    //
    KMERDB_BUILD(
        hq_virus_fna_gz
    )

    //
    // MODULE: Download bacterial genomes and run phist
    //
    PHIST_ARIA2C(
        ch_host_fastas,
        KMERDB_BUILD.out.kdb
    )

    //
    // MODULE: Combine phist results
    //
    ch_phist_combine_input = PHIST_ARIA2C.out.csv_gz
        .map { _meta, tables -> [ [ id:'combined' ], tables ] }
        .collect()

    PHIST_COMBINE(
        ch_phist_combine_input
    )

    emit:
    phist_csv_gz = PHIST_COMBINE.out.csv_gz
}

