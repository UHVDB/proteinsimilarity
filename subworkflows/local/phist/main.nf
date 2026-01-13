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
include { PHIST_BUILD       } from '../../../modules/local/phist/build'
include { PHIST_ARIA2C      } from '../../../modules/local/phist/aria2c'
include { UHVDB_CATHEADER   } from '../../../modules/local/uhvdb/catheader'


// Run entry workflow
workflow PHIST {

    take:
    hq_virus_fna_gz // channel: [ [ meta ], fna.gz ]

    main:

    // Split host URLs into chunks
    ch_host_fastas = channel.fromPath(params.bacterial_host_urls)
        .splitCsv(header: false, strip: true)
        .flatten()
        .collate(params.phist_host_chunk_size)
        .toList()
        .flatMap{ file -> file.withIndex() }
        .map { file, index ->
            [ [ id: 'chunk_' + index ], file ]
        }

    //
    // MODULE: Create kmer-db database from virus fasta
    //
    PHIST_BUILD(
        hq_virus_fna_gz
    )

    //
    // MODULE: Download bacterial genomes and run phist
    //
    PHIST_ARIA2C(
        ch_host_fastas,
        PHIST_BUILD.out.kdb
    )

    //
    // MODULE: Combine outputs with a header
    //
    ch_catheader_input = PHIST_ARIA2C.out.csv_gz.map { _meta, csv_gz -> csv_gz }.collect().map { csv_gz -> [ [ id:'phist' ], csv_gz, 2, 'csv' ] }
    UHVDB_CATHEADER(
        ch_catheader_input,
        "${params.output_dir}/annotate/phist"
    )

    emit:
    phist_csv_gz = UHVDB_CATHEADER.out.combined
}

