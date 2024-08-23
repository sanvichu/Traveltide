import pandas as pd
import ipywidgets as widgets
from IPython.display import display

def print_clusters_as_tab(df, scaled_columns, num_clusters=5):
    tab = widgets.Tab()
    children = []
    
    for cluster in range(num_clusters):
        output = widgets.Output()
        with output:
            print(f"Cluster {cluster}")
            print(df[df['cluster'] == cluster][scaled_columns].mean())
            print('-' * 50)
        children.append(output)
    
    tab.children = children
    for i in range(num_clusters):
        tab.set_title(i, f"Cluster {i}")
    
    display(tab)