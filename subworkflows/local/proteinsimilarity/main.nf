/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT PLUGINS/FUNCTIONS/MODULES/SUBWORKFLOWS/WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
// MODULES
include { DIAMOND_BLASTP                } from '../../../modules/local/diamond/blastp'
include { DIAMOND_BLASTPSELF            } from '../../../modules/local/diamond/blastpself'
include { DIAMOND_MAKEDB                } from '../../../modules/local/diamond/makedb'
include { ICTV_VMRTOFASTA               } from '../../../modules/local/ictv/vmrtofasta'
include { PROTEINSIMILARITY_SELFSCORE   } from '../../../modules/local/proteinsimilarity/selfscore'
include { PROTEINSIMILARITY_NORMSCORE   } from '../../../modules/local/proteinsimilarity/normscore'
include { PROTEINSIMILARITY_COMBINE     } from '../../../modules/local/proteinsimilarity/combine'
include { PYRODIGALGV                   } from '../../../modules/local/pyrodigalgv'

workflow PROTEINSIMILARITY {

    take:
    split_virus_fna_gz // channel: [ [ meta ], fna.gz ]

    main:

    def vmr_dmnd = params.vmr_dmnd ? file(params.vmr_dmnd).exists() : false

    // Prepare ICTV DIAMOND database
    if (!vmr_dmnd) {
        //
        // MODULE: Download ICTV VMR and convert to FASTA
        //
        ch_ictv_vmr = channel.fromPath(params.vmr_url)
            .map { xlsx ->
                [ [ id: "${xlsx.getBaseName()}" ], xlsx ]
            }
        ICTV_VMRTOFASTA(
            ch_ictv_vmr
        )

        //
        // MODULE: Create DIAMOND database from ICTV VMR FASTA
        //
        DIAMOND_MAKEDB(
            ICTV_VMRTOFASTA.out.fna_gz
        )
        ch_vmr_dmnd = DIAMOND_MAKEDB.out.dmnd
    } else {
        ch_vmr_dmnd = channel.fromPath(params.vmr_dmnd)
            .map { dmnd ->
                [ [ id: "${dmnd.getBaseName()}" ], dmnd ]
            }
    }

    //
    // MODULE: Run DIAMOND against ICTV VMR database
    //
    DIAMOND_BLASTP(
        split_virus_fna_gz,
        ch_vmr_dmnd.collect()
    )

    //
    // MODULE: Run DIAMOND against self to calculate self scores
    //
    DIAMOND_BLASTPSELF(
        DIAMOND_BLASTP.out.tsv_gz
    )

    //
    // MODULE: Calculate self scores
    //
    PROTEINSIMILARITY_SELFSCORE(
        DIAMOND_BLASTPSELF.out.tsv_gz
    )

    //
    // MODULE: Calculate normalized bitscore
    //
    ch_normscore_input = PROTEINSIMILARITY_SELFSCORE.out.tsv_gz
        .combine(DIAMOND_BLASTP.out.tsv_gz, by:0)
    PROTEINSIMILARITY_NORMSCORE(
        ch_normscore_input
    )

    // 
    // MODULE: Combine normscore results
    //
    ch_combine_input = PROTEINSIMILARITY_NORMSCORE.out.tsv_gz
        .map { _meta, tsv_gzs -> [ [ id: 'combined'], tsv_gzs ] }
        .groupTuple(sort: 'deep')
    PROTEINSIMILARITY_COMBINE(
        ch_combine_input
    )

    emit:
    proteinsimilarity_tsv_gz = PROTEINSIMILARITY_COMBINE.out.tsv_gz
}
