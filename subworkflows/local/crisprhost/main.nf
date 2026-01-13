/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL PLUGINS/FUNCTIONS/MODULES/SUBWORKFLOWS/WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
// MODULES
include { SEQKIT_SPLIT2                     } from '../../../modules/local/seqkit/split2'
include { SPACEREXTRACTOR_CREATETARGETDB    } from '../../../modules/local/spacerextractor/createtargetdb'
include { SPACEREXTRACTOR_MAPTOTARGET       } from '../../../modules/local/spacerextractor/maptotarget'
include { UHVDB_CATHEADER                   } from '../../../modules/local/uhvdb/catheader'

workflow CRISPRHOST {

    take:
    hq_virus_fna_gz // channel: [ [ meta ], fna.gz ]

    main:

    // Prepare spacer fasta file
    ch_spacer_fasta = channel.fromPath(params.spacer_fasta)
        .map { fasta -> [ [ id: 'spacers' ], fasta ] }

    //-------------------------------------------
    // MODULE: SEQKIT_SPLIT2
    // inputs:
    // - spacers.fna.gz
    // outputs:
    // - [ spacers.part_*.fna.gz... ]
    // steps:
    // - split spacer fasta into chunks of size params.spacer_chunk_size (script)
    //--------------------------------------------
    SEQKIT_SPLIT2(
        ch_spacer_fasta,
        params.spacer_chunk_size
    )
    ch_split_fna_gz = SEQKIT_SPLIT2.out.fastas_gz
        .map { _meta, fna_gzs -> fna_gzs }
        .flatten()
        .map { fna_gz ->
            [ [ id: fna_gz.getBaseName() ], fna_gz ]
        }

    //-------------------------------------------
    // MODULE: SPACEREXTRACTOR_CREATETARGETDB
    // inputs:
    // - [ [ meta ], hq_virus.fna.gz ]
    // outputs:
    // - [ [ meta ], target_db/ ]
    // steps:
    // - uncompress fasta (script)
    // - create spacerextractor target db (script)
    //--------------------------------------------
    SPACEREXTRACTOR_CREATETARGETDB(
        hq_virus_fna_gz
    )

    // //-------------------------------------------
    // // MODULE: SPACEREXTRACTOR_MAPTOTARGET
    // // inputs:
    // // - hq_virus.part_*.fna.gz
    // // - [ [ meta ], target_db/ ]
    // // outputs:
    // // - [ [ meta ], ${meta.id}.spacerextractor_map.tsv.gz ]
    // // steps:
    // // - SE_map_get_hits.py map_to_target (script)
    // // - compress output (script)
    // // - cleanup (script)
    // //--------------------------------------------
    SPACEREXTRACTOR_MAPTOTARGET(
        ch_split_fna_gz,
        SPACEREXTRACTOR_CREATETARGETDB.out.db.collect()
    )

    ch_catheader_input = SPACEREXTRACTOR_MAPTOTARGET.out.tsv_gz.map { _meta, tsv_gz -> tsv_gz }.collect().map { tsv_gz -> [ [ id:'crisprhost' ], tsv_gz, 1, 'tsv' ] }
    UHVDB_CATHEADER(
        ch_catheader_input,
        "${params.output_dir}/annotate/crisprhost"
    )

    emit:
    crisprhost_tsv_gz = UHVDB_CATHEADER.out.combined
}

