/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT PLUGINS/FUNCTIONS/MODULES/SUBWORKFLOWS/WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
// MODULES
include { BAKTA_DOWNLOAD                } from '../../../modules/local/bakta/download'
include { BAKTA_GETMOD                  } from '../../../modules/local/bakta/getmod'
include { BAKTA_VIRUS                   } from '../../../modules/local/bakta/virus'
include { GENETICCODE_SPLIT             } from '../../../modules/local/geneticcodesplit'
include { UNIREF50VIRUS                 } from '../../../modules/local/uniref50virus'


workflow BAKTA {

    take:
    split_virus_fna_gz      // channel: [ [ meta ], virus.split.fna.gz ]
    virus_summary_tsv_gz    // channel: [ [ meta ], virus.summary.tsv.gz ]

    main:

    //-------------------------------------
    // Download databases
    //-------------------------------------
    //
    // MODULE: Download Bakta database
    //
    BAKTA_DOWNLOAD()

    //
    // MODULE: Download modified Bakta
    //
    BAKTA_GETMOD(params.bakta_mod_url)

    //
    // MODULE: Split input FNA based on genetic code
    //
    GENETICCODE_SPLIT(
        split_virus_fna_gz,
        virus_summary_tsv_gz
    )
    ch_gcode_split_fna_gz = GENETICCODE_SPLIT.out.fna_gzs
        .map { _meta, fna_gzs -> fna_gzs }
        .flatten()
        .map { fna_gz ->
            def g_code = fna_gz.getBaseName().toString() =~ /gcode(\d+)/
            [ [ id: fna_gz.getBaseName(), g_code: g_code[0][1] ], fna_gz ]
        }

    //
    // MODULE: Download UniRef50 virus sequences
    //
    UNIREF50VIRUS()

    //
    // MODULE: Predict features and annotate with BAKTA
    //
    BAKTA_VIRUS(
        ch_gcode_split_fna_gz,
        BAKTA_DOWNLOAD.out.db.collect(),
        UNIREF50VIRUS.out.faa_gz.collect(),
        BAKTA_GETMOD.out.bakta_mod.collect()
    )

    emit:
    bakta_gbk_gz    = BAKTA_VIRUS.out.gbk_gz // (for referenceanalyze subworkflow)
    bakta_faa_gz    = BAKTA_VIRUS.out.faa_gz // (for proteinsimilarity + aaicluster subworkflows)
}

