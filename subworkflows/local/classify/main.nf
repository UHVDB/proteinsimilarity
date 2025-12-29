/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Classify
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL PLUGINS/FUNCTIONS/MODULES/SUBWORKFLOWS/WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { ENA_GENOMAD                   } from '../../../modules/local/ena/genomad'
include { LOGAN_GENOMAD as ATB_GENOMAD  } from '../../../modules/local/logan/genomad'
include { NCBI_GENOMAD                  } from '../../../modules/local/ncbi/genomad'
include { GENOMAD_DOWNLOADDATABASE      } from '../../../modules/local/genomad/downloaddatabase'
// include { GENOMAD_ENDTOEND              } from '../../../modules/local/genomad/endtoend'
include { SEQKIT_SPLIT2                 } from '../../../modules/local/seqkit/split2'
// include { SEQKIT_SEQ                    } from '../../../modules/local/seqkit/seq'


//
// WORFKLOW: Classify viruses in input fasta files
//
workflow CLASSIFY {

    take:
    fna_gz  // channel: [ [ meta ], fna.gz ]

    main:

    //
    // MODULE: Download geNomad database
    //
    GENOMAD_DOWNLOADDATABASE()

    // Initialize output channels
    def ch_virus_summaries_tsv_gz = channel.empty()
    def ch_genomad_genes_tsv_gz = channel.empty()
    def ch_virus_fna_gz = channel.empty()

    //
    // MODULE: Mine viruses from ATB assemblies
    //
    def ch_atb_assembly_batches = fna_gz.filter { meta, _fasta -> meta.source_db == 'ATB' }
        .map { meta, fasta -> [ meta.release, meta.id, fasta ] }
        .collate(1000)
        .toList()
        .flatMap{ rel_id_fasta -> rel_id_fasta.withIndex() }
        .map { rel_id_fasta, index ->
            [ [ id: 'atb_batch_' + index, source_db: 'ATB', release: rel_id_fasta[0][0] ], rel_id_fasta ]
        }
    ATB_GENOMAD(
        ch_atb_assembly_batches,
        GENOMAD_DOWNLOADDATABASE.out.genomad_db
    )
    ch_virus_summaries_tsv_gz   = ch_virus_summaries_tsv_gz.mix(ATB_GENOMAD.out.summary_tsv_gz)
    ch_virus_fna_gz             = ch_virus_fna_gz.mix(ATB_GENOMAD.out.fna_gz)
    ch_genomad_genes_tsv_gz     = ch_genomad_genes_tsv_gz.mix(ATB_GENOMAD.out.genes_tsv_gz)

    //
    // MODULE: Mine viruses from ENA assemblies
    //
    def ch_ena_urls = fna_gz.filter { meta, _fasta -> meta.source_db == 'ENA' }
        .map { meta, fasta -> [ meta.release, meta.id, fasta ] }
        .collate(10)
        .toList()
        .flatMap{ rel_id_fasta -> rel_id_fasta.withIndex() }
        .map { rel_id_fasta, index ->
            [ [ id: rel_id_fasta[0][3].toLowerCase() + '_batch_' + index, source_db: 'ENA', release: rel_id_fasta[0][0] ], rel_id_fasta ]
        }
    ENA_GENOMAD(
        ch_ena_urls,
        GENOMAD_DOWNLOADDATABASE.out.genomad_db
    )
    ch_virus_summaries_tsv_gz   = ch_virus_summaries_tsv_gz.mix(ENA_GENOMAD.out.summary_tsv_gz)
    ch_virus_fna_gz             = ch_virus_fna_gz.mix(ENA_GENOMAD.out.fna_gz)
    ch_genomad_genes_tsv_gz     = ch_genomad_genes_tsv_gz.mix(ENA_GENOMAD.out.genes_tsv_gz)

    //
    // MODULE: Mine virus sequences from NCBI GenBank
    //
    def ch_ncbi_virus_urls = fna_gz.filter { meta, _fasta -> meta.source_db == 'NCBI_VIRUS' }
        .map { meta, fasta -> [ meta.release, meta.id, fasta ] }
        .collate(1000)
        .toList()
        .flatMap{ rel_id_fasta -> rel_id_fasta.withIndex() }
        .map { rel_id_fasta, index ->
            [ [ id: rel_id_fasta[0][3].toLowerCase() + '_batch_' + index, source_db: 'NCBI_VIRUS', release: rel_id_fasta[0][0] ], rel_id_fasta ]
        }
    NCBI_GENOMAD(
        ch_ncbi_virus_urls,
        GENOMAD_DOWNLOADDATABASE.out.genomad_db
    )
    ch_virus_summaries_tsv_gz   = ch_virus_summaries_tsv_gz.mix(NCBI_GENOMAD.out.summary_tsv_gz)
    ch_virus_fna_gz             = ch_virus_fna_gz.mix(NCBI_GENOMAD.out.fna_gz)
    ch_genomad_genes_tsv_gz     = ch_genomad_genes_tsv_gz.mix(NCBI_GENOMAD.out.genes_tsv_gz)


    //
    // MODULE: Mine virus from local fasta files
    //
    def ch_local_fastas = fna_gz.filter { meta, _fasta ->
            (
                meta.source_db != "ENA" &&
                meta.source_db != "NCBI_VIRUS" &&
                meta.source_db != "LOGAN" &&
                meta.source_db != "SPIRE" &&
                meta.source_db != "ATB"
            )
        }
        .map { meta, fasta -> [ meta, fasta ] }

    // SEQKIT_SEQ(
    //     ch_local_fastas
    // )

    // SEQKIT_SPLIT2(
    //     SEQKIT_SEQ.out.fasta,
    // )

    // ch_split_fastas = SEQKIT_SPLIT2.out.fastas
    //     .map { file -> file }
    //     .flatten()
    //     .map { file ->
    //         [ [ id: file.getBaseName() ], file ]
    //     }

    // GENOMAD_ENDTOEND(
    //     ch_local_fastas,
    //     GENOMAD_DOWNLOADDATABASE.out.genomad_db
    // )
    // ch_virus_summaries_tsv_gz   = ch_virus_summaries_tsv_gz.mix(GENOMAD_ENDTOEND.out.summary_tsv_gz)
    // ch_virus_fna_gz             = ch_virus_fna_gz.mix(GENOMAD_ENDTOEND.out.fna_gz)
    // ch_genomad_genes_tsv_gz     = ch_genomad_genes_tsv_gz.mix(GENOMAD_ENDTOEND.out.genes_tsv_gz)

    //
    // MODULE: Mine viruses from Logan assemblies
    //
    // load logan assemblies in specified batch size
    def ch_logan_assembly_batches = ch_uhvdb_mine_input.filter { meta, _tar, _fasta -> meta.source_db == 'LOGAN' }
        .map { meta, _tar, fasta -> [ meta.release, meta.id, fasta ] }
        .collate(100)
        .toList()
        .flatMap{ rel_id_fasta -> rel_id_fasta.withIndex() }
        .map { rel_id_fasta, index ->
            [ [ id: 'logan_batch_' + index, source_db: 'LOGAN', release: rel_id_fasta[0][0] ], rel_id_fasta ]
        }

    LOGAN_GENOMAD(
        ch_logan_assembly_batches,
        ch_genomad_db
    )

    ch_virus_summaries_tsv_gz   = ch_virus_summaries_tsv_gz.mix(LOGAN_GENOMAD.out.virus_summary)
    ch_virus_fna_gz             = ch_virus_fna_gz.mix(LOGAN_GENOMAD.out.virus_fna)
    ch_genomad_genes_tsv_gz     = ch_genomad_genes_tsv_gz.mix(LOGAN_GENOMAD.out.genes)

    //
    // MODULE: Run geNomad on SPIRE
    //
    // load spire assemblies and group into specified batch size
    def ch_spire_urls = ch_uhvdb_mine_input.filter { meta, _tar, _fasta -> meta.source_db == 'SPIRE' }
        .map { meta, _tar, fasta -> [ meta.release, meta.id, fasta, meta.source_db ] }
        .collate(5)
        .toList()
        .flatMap{ rel_id_fasta_db -> rel_id_fasta_db.withIndex() }
        .map { rel_id_fasta_db, index ->
            [ [ id: rel_id_fasta_db[0][3].toLowerCase() + '_batch_' + index, source_db: rel_id_fasta_db[0][3], release: rel_id_fasta_db[0][0] ], rel_id_fasta_db ]
        }

    SPIRE_GENOMAD(
        ch_spire_urls,
        ch_genomad_db
    )

    ch_virus_summaries_tsv_gz   = ch_virus_summaries_tsv_gz.mix(SPIRE_GENOMAD.out.virus_summary)
    ch_virus_fna_gz             = ch_virus_fna_gz.mix(SPIRE_GENOMAD.out.virus_fna)
    ch_genomad_genes_tsv_gz     = ch_genomad_genes_tsv_gz.mix(SPIRE_GENOMAD.out.genes)

    // combine virus summaries and fasta files into one channel
    def ch_genomad_filter_input = ch_virus_summaries_tsv_gz
        .combine(rmEmptyFastAs(ch_virus_fna_gz, false), by:0)
}

