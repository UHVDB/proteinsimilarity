#!/usr/bin/env python

import argparse
import csv
import gzip
import os
import polars as pl
import shutil

from collections import defaultdict

pl.Config.set_streaming_chunk_size(10_000)

def parse_args(args=None):
    description = "Calculate the normalized bitscore for a genome."
    epilog = "Example usage: python uhvdb_normscore.py --help"

    parser = argparse.ArgumentParser(description=description, epilog=epilog)
    parser.add_argument(
        "-i",
        "--input",
        help="Path to TSV created by DIAMOND.",
    )
    parser.add_argument(
        "-s",
        "--self_score",
        help="Path to self score TSV created using self_score.py.",
    )
    parser.add_argument(
        "-m",
        "--min_score",
        help="Minimum normscore to output.",
        type=int,
        default=0
    )
    parser.add_argument(
        "-o",
        "--output",
        help="Output TSV containing normalized bitscore.",
    )
    parser.add_argument('--version', action='version', version='1.0.0')
    return parser.parse_args(args)


def aai_main(input, self_score, output, min_score):

    # read self score and convert to dict
    self_score_df = pl.read_parquet(self_score).select(['genome', 'selfscore'])
    self_score_dict = {k: v[0] for k, v in self_score_df.rows_by_key(key=["genome"], unique=True).items()}

    # read ref parquet
    norm_score = (
        pl.scan_parquet(input)
            .select(['column00', 'column01', 'column11']) # select subset of columns
            .rename({'column00':'q_gene', 'column01':'r_gene', 'column11':'bitscore'}) # rename columns
            .with_columns([
                pl.col('q_gene').str.replace(r'_\d+$', '').cast(pl.Categorical).alias('query'), # extract genome IDs
                pl.col('r_gene').str.replace(r'_\d+$', '').cast(pl.Categorical).alias('reference'),
                pl.col('q_gene').cast(pl.Categorical)
            ])
            .filter(pl.col('query') != 'reference') # do not look at self hits
            .group_by(['q_gene', 'query', 'reference']) 
            .agg([pl.col('bitscore').max()]) # keep only one query_gene -> ref_genome hit (top scoring)
            .group_by(['query', 'reference'])
            .agg([
                pl.col('bitscore').sum().alias('raw_score') # sum all bitscores between query -> reference
            ])
            .with_columns([
                pl.col('query').cast(pl.String).replace(self_score_dict).cast(pl.Float32).alias('self_score') # map self scores to query
            ])
            .with_columns([
                (100 * pl.col('raw_score') / pl.col('self_score')).alias('norm_score') # calculate norm_score
            ])
            .filter(pl.col('norm_score') >= min_score)
            .select(['query', 'reference', 'norm_score'])
    )

    norm_score.sink_csv(output, separator='\t', float_precision=2, include_header=False)


def main(args=None):
    args = parse_args(args)

    aai_main(args.input, args.self_score, args.output, args.min_score)

if __name__ == "__main__":
    main()
