/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT PLUGINS/FUNCITONS/MODULES/SUBWORKFLOWS/WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
// MODULES
include { GENOMAD_DOWNLOADDATABASE          } from '../../../modules/local/genomad/downloaddatabase'
include { GENOMAD_ENDTOEND                  } from '../../../modules/local/genomad/endtoend'
include { SEQHASHER                         } from '../../../modules/local/seqhasher'
include { SEQKIT_SPLIT2 as SPLIT_INPUTS     } from '../../../modules/local/seqkit/split2'
include { SEQKIT_SPLIT2 as SPLIT_GENOMAD    } from '../../../modules/local/seqkit/split2'
include { UHVDB_UNIQUEHASH                  } from '../../../modules/local/uhvdb/uniquehash'
include { UHVDB_CATHEADER                   } from '../../../modules/local/uhvdb/catheader'
include { UHVDB_CATNOHEADER                 } from '../../../modules/local/uhvdb/catnoheader'

workflow UNIQUE {
    take:
    input_virus_fastas  // channel: [ [ meta ], viruses.fna.gz ]

    main:
    //-------------------------------------------
    // MODULE: SEQHASHER
    // inputs:
    // - [ [ meta ], virus.fna.gz ]
    // - rename (boolean)
    // outputs:
    // - [ [ meta ], virus.seqhasher.tsv.gz ]
    // steps:
    // - Add prefix (script)
    // - Trim DTRs (script)
    // - Calculate sequence hashes (script)
    // - Compress output (script)
    // - Cleanup (script)
    //-------------------------------------------
    SEQHASHER(
        input_virus_fastas,
        true
    )

    //-------------------------------------------
    // MODULE: UHVDB_UNIQUEHASH
    // inputs:
    // - [ [ meta ], [ virus.seqhasher.part_*.tsv.gz ... ] ]
    // outputs:
    // - [ [ meta ], virus.unique.tsv.gz ]
    // steps:
    // - Concatenate TSVs (script)
    // - Identify unique hashes (script)
    // - Write out tsv (script)
    // - Write out fasta (script)
    // - Cleanup (script)
    //-------------------------------------------
    ch_unique_input = SEQHASHER.out.tsv_gz
        .map { _meta, tsv_gz -> [ tsv_gz ] }
        .collect()
        .map { tsv_gzs -> [ [ id:'input_viruses' ], tsv_gzs ] }
    UHVDB_UNIQUEHASH(
        ch_unique_input,
        "${params.output_dir}/${params.new_release_id}/unique/seqhasher"
    )

    //-------------------------------------------
    // MODULE: SPLIT_INPUTS
    // inputs:
    // - [ [ meta ], unique_viruses.fna.gz ]
    // outputs:
    // - [ [ meta ], [ unique_virus_chunk.part_*.fna.gz ... ] ]
    // steps:
    // - Split fasta into chunks (script)
    //--------------------------------------------
    SPLIT_INPUTS(
        UHVDB_UNIQUEHASH.out.fna_gz,
        params.fasta_chunk_size
    )
    ch_unique_input_viruses_split_fna_gz = SPLIT_INPUTS.out.fastas_gz
        .map { _meta, fna_gzs -> fna_gzs }
        .flatten()
        .map { fna_gz ->
            [ [ id: fna_gz.getBaseName() ], fna_gz ]
        }

    //-------------------------------------------
    // MODULE: GENOMAD_DOWNLOADDATABASE
    // outputs:
    // - database
    // steps:
    // - download genomad database (script)
    //-------------------------------------------
    GENOMAD_DOWNLOADDATABASE()

    //-------------------------------------------
    // MODULE: GENOMAD_ENDTOEND
    // inputs:
    // - [ [ meta ], unique_virus.part_*.fna.gz ]
    // - database
    // outputs:
    // - [ [ meta ], unique_virus_genomad.part_*.fna.gz ]
    // - [ [ meta ], unique_virus_genomad.part_*.summary.tsv.gz ]
    // - [ [ meta ], unique_virus_genomad.part_*.tsv.gz ]
    // steps:
    // - Run genomad (script)
    // - Compress outputs (script)
    // - Cleanup (script)
    //-------------------------------------------
    GENOMAD_ENDTOEND(
        ch_unique_input_viruses_split_fna_gz,
        GENOMAD_DOWNLOADDATABASE.out.genomad_db.collect()
    )

    //-------------------------------------------
    // MODULE: UHVDB_CATNOHEADER
    // inputs:
    // - [ [ meta ], [ unique_virus_genomad_chunk.part_*.fna.gz ... ] ]
    // outputs:
    // - [ [ meta ], unique_virus_genomad.fna.gz ]
    // steps:
    // - Combine files (script)
    //--------------------------------------------
    ch_catnoheader_input = GENOMAD_ENDTOEND.out.fna_gz.map { _meta, fna_gz -> fna_gz }.collect().map { fna_gz -> [ [ id:'genomad_viruses' ], fna_gz, 'fna.gz' ] }
    UHVDB_CATNOHEADER(
        ch_catnoheader_input,
        "${params.output_dir}/${params.new_release_id}/unique/genomad/"
    )

    //-------------------------------------------
    // MODULE: UHVDB_CATHEADER
    // inputs:
    // - [ [ meta ], [ unique_virus_genomad_chunk.part_*.tsv.gz ... ] ]
    // outputs:
    // - [ [ meta ], unique_virus_genomad.tsv.gz ]
    // steps:
    // - Combine files (script)
    //--------------------------------------------
    ch_catheader_input = GENOMAD_ENDTOEND.out.summary_tsv_gz.map { _meta, tsv_gz -> tsv_gz }.collect().map { tsv_gz -> [ [ id:'genomad_viruses' ], tsv_gz, 1, 'tsv' ] }
    UHVDB_CATHEADER(
        ch_catheader_input,
        "${params.output_dir}/${params.new_release_id}/unique/genomad/"
    )

    //-------------------------------------------
    // MODULE: SPLIT_GENOMAD
    // inputs:
    // - [ [ meta ], unique_virus_genomad.fna.gz ]
    // outputs:
    // - [ [ meta ], [ unique_virus_genomad_chunk.part_*.fna.gz ... ] ]
    // steps:
    // - Split fasta into chunks (script)
    //--------------------------------------------
    SPLIT_GENOMAD(
        UHVDB_CATNOHEADER.out.combined,
        params.fasta_chunk_size
    )
    ch_unique_genomad_viruses_fna_gz = SPLIT_GENOMAD.out.fastas_gz
        .map { _meta, fna_gzs -> fna_gzs }
        .flatten()
        .map { fna_gz ->
            [ [ id: fna_gz.getBaseName() ], fna_gz ]
        }

    emit:
    virus_fna_gz            = UHVDB_CATNOHEADER.out.combined
    virus_split_fna_gz      = ch_unique_genomad_viruses_fna_gz
    virus_summary_tsv_gz    = UHVDB_CATHEADER.out.combined
}
