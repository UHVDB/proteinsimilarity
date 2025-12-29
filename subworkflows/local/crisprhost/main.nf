/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL PLUGINS/FUNCTIONS/MODULES/SUBWORKFLOWS/WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
// MODULES
include { SEQKIT_SPLIT2                     } from '../../../modules/local/seqkit/split2'
include { SPACEREXTRACTOR_COMBINERESULTS    } from '../../../modules/local/spacerextractor/combineresults'
include { SPACEREXTRACTOR_CREATETARGETDB    } from '../../../modules/local/spacerextractor/createtargetdb'
include { SPACEREXTRACTOR_MAPTOTARGET       } from '../../../modules/local/spacerextractor/maptotarget'

workflow CRISPRHOST {

    take:
    hq_virus_fna_gz // channel: [ [ meta ], fna.gz ]

    main:

    // Prepare spacer fasta file
    ch_spacer_fasta = channel.fromPath(params.spacer_fasta)

    //-------------------------------------------
    // MODULE: SEQKIT_SPLIT2
    // inputs:
    // - spacers.fna.gz
    // outputs:
    // - [ spacers.part_*.fna.gz... ]
    // steps:
    // - split spacer fasta into chunks of size params.crisprhost_chunk_size (script)
    //--------------------------------------------
    SEQKIT_SPLIT2(
        ch_spacer_fasta,
        params.crisprhost_chunk_size
    )

    ch_split_fastas = SEQKIT_SPLIT2.out.fastas_gz
        .map { file -> file }
        .flatten()
        .map { file ->
            [ [ id: file.getBaseName() ], file ]
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

    //-------------------------------------------
    // MODULE: SPACEREXTRACTOR_MAPTOTARGET
    // inputs:
    // - hq_virus.part_*.fna.gz
    // - [ [ meta ], target_db/ ]
    // outputs:
    // - [ [ meta ], ${meta.id}.spacerextractor_map.tsv.gz ]
    // steps:
    // - SE_map_get_hits.py map_to_target (script)
    // - compress output (script)
    // - cleanup (script)
    //--------------------------------------------
    SPACEREXTRACTOR_MAPTOTARGET(
        ch_split_fastas,
        SPACEREXTRACTOR_CREATETARGETDB.out.db.collect()
    )

    //-------------------------------------------
    // MODULE: SPACEREXTRACTOR_COMBINERESULTS
    // inputs:
    // - [ *.spacerextractor_map.tsv.gz ...  ]
    // outputs:
    // - combined.spacerextractor.tsv.gz
    // steps:
    // - concatenate results TSVs (script)
    // - compress output (script)
    //--------------------------------------------
    SPACEREXTRACTOR_COMBINERESULTS(
        SPACEREXTRACTOR_MAPTOTARGET.out.tsv_gz.map { _meta, tsvs -> [ tsvs ] }.collect()
    )

    emit:
    crisprhost_tsv_gz = SPACEREXTRACTOR_COMBINERESULTS.out.tsv_gz
}

