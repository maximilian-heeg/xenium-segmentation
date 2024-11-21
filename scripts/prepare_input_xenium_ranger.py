#!/usr/bin/env python3
"""
Xenium Data Processing Script
Copyright (c) 2024

A script for processing Xenium spatial transcriptomics data and preparing it for visualization
in Xenium Explorer. It performs the following steps:
1. Reads transcript data with cell assignments
2. Creates cell boundary polygons using alpha shapes
3. Handles multi-polygon merging and selection
4. Generates GeoJSON output for visualization
5. Updates transcript cell assignments based on valid polygons
6. Produces Ranger-compatible CSV output

The alpha parameter controls the shape of the cell boundaries.
"""

import numpy as np
import pandas as pd
from alphashape import alphashape
import json
from shapely.geometry import MultiPolygon
from shapely.ops import unary_union
from multiprocessing import Pool, cpu_count
from functools import partial
from tqdm import tqdm
import argparse

def process_cell(cell_data, alpha=0.05):
    """
    Process a single cell to create its geometry, merging multiple polygons if present.
    
    Args:
        cell_data: Tuple of (cell_id, points_dataframe)
        alpha: Alpha value for the alphashape algorithm
    
    Returns:
        dict or None: Geometry dictionary if successful, None if failed
    """
    cell_id, group = cell_data
    points = group[['x', 'y']].values
    
    if len(points) < 3:
        return None
        
    try:
        alpha_shape = alphashape(points, alpha)
        
        if isinstance(alpha_shape, MultiPolygon):
            merged_shape = unary_union(alpha_shape)
            if isinstance(merged_shape, MultiPolygon):
                largest_poly = max(merged_shape.geoms, key=lambda p: p.area)
                coordinates = [list(coord) for coord in largest_poly.exterior.coords]
            else:
                coordinates = [list(coord) for coord in merged_shape.exterior.coords]
        else:
            coordinates = [list(coord) for coord in alpha_shape.exterior.coords]
        
        geometry = {
            "type": "Polygon",
            "coordinates": [coordinates],
            "cell": cell_id
        }
        return geometry
    
    except Exception:
        return None

def create_multicell_geojson_parallel(df, x_col='x', y_col='y', cell_col='cell', alpha=0.0, n_processes=None):
    """
    Create a GeoJSON from a pandas DataFrame containing points grouped by cell,
    processing cells in parallel.
    """
    df = df.rename(columns={x_col: 'x', y_col: 'y', cell_col: 'cell'})
    
    if n_processes is None:
        n_processes = max(1, cpu_count() - 1)
    
    grouped = df.groupby('cell')
    total_cells = len(grouped)
    
    process_cell_partial = partial(process_cell, alpha=alpha)
    
    with Pool(processes=n_processes) as pool:
        geometries = list(tqdm(
            pool.imap(process_cell_partial, grouped),
            total=total_cells,
            desc="Processing cells",
            unit="cell"
        ))
    
    geometries = [g for g in geometries if g is not None]
    
    geojson = {
        "type": "GeometryCollection",
        "geometries": geometries
    }
    
    return geojson

def save_geojson(geojson, filename):
    """Save GeoJSON to a file"""
    with open(filename, 'w') as f:
        json.dump(geojson, f, indent=2)

def main():
    parser = argparse.ArgumentParser(description='Process Xenium data and create GeoJSON output')
    parser.add_argument('--input', required=True, help='Input CSV file path')
    parser.add_argument('--output-geojson', required=True, help='Output GeoJSON file path')
    parser.add_argument('--output-csv', required=True, help='Output CSV file path')
    parser.add_argument('--alpha', type=float, default=0.0, help='Alpha value for the alphashape algorithm')
    parser.add_argument('--prefix', default='prefix-', help='Prefix for cell IDs')
    args = parser.parse_args()

    # Read and process input data
    print("Reading input data...")
    df = pd.read_csv(args.input)
    df['is_noise'] = df['cell'].isna()
    df['cell'] = df['cell'].astype('category').cat.codes
    df.loc[df['is_noise'], 'cell'] = ''

    # Create GeoJSON
    print("Creating GeoJSON...")
    result = create_multicell_geojson_parallel(
        df[~df['is_noise']],
        x_col='x',
        y_col='y',
        cell_col='cell',
        alpha=args.alpha
    )
    
    # Save GeoJSON
    save_geojson(result, args.output_geojson)
    
    # Update cell IDs and noise flags
    valid_cells = [r['cell'] for r in result['geometries']]
    mask = ~df['cell'].isin(valid_cells)
    df['cell'] = args.prefix + df['cell'].astype(str)
    df.loc[mask, 'cell'] = ''
    df.loc[mask, 'is_noise'] = True
    
    # Save processed CSV
    df.to_csv(args.output_csv, index=False)
    
    print(f"Processed {len(result['geometries'])} cells successfully")
    print(f"Total unique cells: {len(df['cell'].unique())}")

if __name__ == "__main__":
    main()