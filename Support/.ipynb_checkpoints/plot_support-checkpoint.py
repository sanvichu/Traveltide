import plotly.graph_objects as go
import plotly.express as px
import plotly.io as pio
from plotly.subplots import make_subplots
import os
import pandas as pd
import numpy as np
# To resolve the git dynamic image rendring issue, for ploty chart, i enable it as a static image. you can disable to create Dynamic charts in your notbook
pio.renderers.default = "png"


# Plot enblow curve
def plot_elbow_curve(model, data, cluster_ranges):
    inertia_values = []
    
    for i in cluster_ranges:
        model.set_params(n_clusters=i)
        model.fit(data)
        inertia_values.append(model.inertia_)

    # Create the plot using Plotly
    fig = go.Figure()

    # Add a line plot for inertia values
    fig.add_trace(go.Scatter(
        x=list(cluster_ranges), 
        y=inertia_values, 
        mode='lines+markers', 
        marker=dict(symbol='circle', size=8),
        name='Inertia'
    ))

    # Add title and labels
    fig.update_layout(
        title="Elbow Curve",
        xaxis_title="Number of clusters",
        yaxis_title="Inertia",
        template="plotly_white"
    )

    # Show the plot
    fig.show()

# Correlation heatmap between scaled values
def plot_correlation_heatmap(correlation_matrix,  title='Correlation Matrix of Metrics'):
    """
    Generate, save, and display a Plotly heatmap for the correlation matrix.

    Parameters:
    - correlation_matrix: pandas DataFrame representing the correlation matrix
    - img_dir_path: directory path where the heatmap image will be saved
    - file_name: name of the file to save the heatmap (default is 'CorrelationVerification.png')
    - title: title of the heatmap (default is 'Correlation Matrix of Metrics')
    """
    # Generate the heatmap
    fig = px.imshow(
        correlation_matrix,
        text_auto=".2f",
        color_continuous_scale='RdBu_r',  # Red to blue color map, similar to 'coolwarm'
        title=title,
        aspect='auto'  # Adjust the aspect ratio
    )

    # Update layout for better appearance
    fig.update_layout(
        width=1000,  # Adjust width
        height=800,  # Adjust height
        xaxis=dict(tickangle=45, tickmode='array'),
    )

   
    # Display the heatmap
    fig.show()


# correlation heatmap betwen cluster and scaled columns
def plot_cluster_heatmap(df, cluster_column, scaled_columns, label_column, title='Traveller Groups Heatmap'):
    """
    Create a Plotly heatmap for cluster characteristics.

    Parameters:
    - df: pandas DataFrame containing the data
    - cluster_column: the name of the column containing cluster labels
    - scaled_columns: list of columns to be included in the heatmap
    - label_column: the name of the column containing custom labels for clusters
    - title: title of the heatmap
    """
    # Step 1: Compute mean values for each cluster
    cluster_summaries = {}  # Dictionary to store mean values for each cluster

    for cluster in df[cluster_column].unique():  # Loop over all unique clusters
        sub_df = df[df[cluster_column] == cluster]
        cluster_summaries[cluster] = sub_df[scaled_columns].mean()

    # Step 2: Convert the dictionary into a DataFrame for visualization
    cluster_summary_df = pd.DataFrame.from_dict(cluster_summaries, orient='index', columns=scaled_columns)

    # Step 3: Transpose the DataFrame for a better heatmap layout
    cluster_summary_transposed = cluster_summary_df.T

    # Step 4: Define custom x-axis labels for the clusters
    custom_x_labels = df[label_column].unique().tolist()

    # Set the custom labels to the DataFrame
    cluster_summary_transposed.columns = custom_x_labels

    # Step 5: Create a heatmap using Plotly
    fig = px.imshow(
        cluster_summary_transposed,
        color_continuous_scale='RdBu_r',  # Red to blue color map
        aspect='auto',
        text_auto='.3f',  # Annotate the heatmap cells with values
        labels=dict(x='Clusters', y='Features', color='Mean Scaled Value'),  # Axis labels and color bar label
        title=title  # Title of the heatmap
    )

    # Step 6: Customize the heatmap appearance
    fig.update_layout(
        width=1000,  # Adjust width
        height=800,
        xaxis=dict(
            tickmode='array',
            tickvals=list(range(len(custom_x_labels))),
            ticktext=custom_x_labels,
            tickangle=45
        ),
        yaxis_title='Features',
        xaxis_title='Clusters',
        title=dict(text=title, x=0.5),
        title_font_size=20
    )

    # Step 7: Show the heatmap
    fig.show()


# Stacked bar chart with percentages
def plot_stacked_bar_with_percentages(df, x_col, y_col, x_label='X Axis', y_label='Y Axis', title='Stacked Bar Chart'):
    """
    Create a stacked bar chart in Plotly with percentages inside the bars, similar to the example image.

    Parameters:
    - df: pandas DataFrame containing the data.
    - x_col: the name of the column to use for the x-axis.
    - y_col: the name of the column to use for the y-axis.
    - x_label: label for the x-axis (default is 'X Axis').
    - y_label: label for the y-axis (default is 'Y Axis').
    - title: title of the stacked bar chart (default is 'Stacked Bar Chart').
    """
    # Create a crosstab to summarize the data
    crosstab = pd.crosstab(df[x_col], df[y_col])

    # Calculate the total for each x category
    totals = crosstab.sum(axis=1)

    # Calculate percentages for each y value within each x category
    percentages = crosstab.div(totals, axis=0) * 100

    # Create a figure
    fig = go.Figure()

    # Create traces for each y value
    for col in crosstab.columns:
        fig.add_trace(go.Bar(
            x=crosstab.index,
            y=crosstab[col],
            text=[f'{p:.2f}%' for p in percentages[col]],  # Format: "percentage usa"
            textposition='inside',
            insidetextanchor='middle',
            name=col
        ))

    # Update layout
    fig.update_layout(
        width=1000,  # Adjust width
        height=800,  # Adjust height
        barmode='stack',  # Stack bars
        xaxis_title=x_label,
        yaxis_title=y_label,
        title=dict(text=title, x=0.5),
        title_font_size=20
    )

    # Rotate x-axis labels for readability
  #  fig.update_xaxes(tickangle=45)

    # Show the plot
    fig.show()

# user behaviour accross difffernt Metrics
def plot_user_behavior(df, x_column, y_columns, x_labels, y_axis_label, chart_title):
    """
    Generic function to create a Plotly bar chart for visualizing user behavior metrics.

    Parameters:
    - df (pd.DataFrame): Data frame containing the user behavior data.
    - x_column (str): Column name for the x-axis (typically 'cluster' or similar categorical variable).
    - y_columns (list of str): List of column names for the metrics to plot (e.g., ['total_trips', 'total_cancellations', 'conversion_rate']).
    - x_labels (list of str): Custom labels for x-axis categories.
    - y_axis_label (str): Label for the y-axis.
    - chart_title (str): Title of the chart.
    - file_path (str, optional): Path to save the image file. If None, the chart is not saved.

    Returns:
    - fig: Plotly figure object.
    """
    # Get unique cluster IDs and initialize the lists to store metric sums
    unique_clusters = np.sort(df[x_column].unique())

    # Store sum of each metric for each cluster
    y_sums = {col: [df[df[x_column] == cluster][col].sum() for cluster in unique_clusters] for col in y_columns}
    
    # Create bar traces for each metric
    traces = []
    for i, col in enumerate(y_columns):
        traces.append(go.Bar(
            x=x_labels,
            y=y_sums[col],
            name=col,
            marker=dict(color=['#636EFA', '#EF553B', '#00CC96'][i % 3]), # Different colors for bars
            offsetgroup=i  # Ensures grouped bars
        ))
    
    # Create the figure
    fig = go.Figure(data=traces)
    
    # Update layout for the figure
    fig.update_layout(
        barmode='group',
        title=chart_title,
        yaxis=dict(title=y_axis_label),
        xaxis=dict(title='Clusters', tickvals=list(range(len(x_labels))), ticktext=x_labels, tickangle=45),
        width=1000,
        height=600
    )

   
    # Display the chart
  
    fig.show()

# pie chart for cluster
def plot_cluster_pie_chart(df):
    # Extract cluster counts from the DataFrame
    cluster_counts = df['cluster_label'].value_counts()
    
    # Prepare the data
    labels = cluster_counts.index
    values = cluster_counts.values

    # Create the pie chart
    fig = go.Figure(data=[go.Pie(
        labels=labels,       # Cluster names for the legend
        values=values,       # Count of each cluster
        hole=0.5,            # Optional: for a donut chart; remove this for a standard pie chart
        textinfo='percent',  # Show percentages on slices
        insidetextorientation='radial',  # Ensures text is oriented for readability
        showlegend=True      # Display legend with cluster names
    )])

    # Update the layout
    fig.update_layout(
        title_text='Distribution of Clusters',
        legend_title='Cluster Names',  # Title for the legend
        annotations=[dict(text='', x=0.5, y=0.5, font_size=20, showarrow=False)]
    )
    
    # Show the chart
    fig.show()

# Sunburst chat
def plot_sunburst_chart(df, 
                        cluster_column='cluster_label', 
                        category_column='home_city', 
                        value_column='count', 
                        top_n=5, 
                        chart_title='Top Preferences by Cluster'):
    """
    Create a generic sunburst chart to visualize the top N category preferences by cluster label.

    Parameters:
    - df (pd.DataFrame): Dataframe containing the cluster and category information.
    - cluster_column (str): Name of the column representing the cluster label.
    - category_column (str): Name of the column representing the category (e.g., city, country).
    - value_column (str): Name of the column representing the value/count for sizing the chart segments.
    - top_n (int): Number of top categories to display per cluster.
    - chart_title (str): Title of the chart.
    """
    # Calculate the count of categories per cluster
    category_counts = df.groupby([cluster_column, category_column]).size().reset_index(name=value_column)

    # Find the top N categories for each cluster
    top_categories = category_counts.groupby(cluster_column, group_keys=False).apply(lambda x: x.nlargest(top_n, value_column)).reset_index(drop=True)

    # Create the sunburst chart
    fig = px.sunburst(top_categories,
                      path=[cluster_column, category_column],  # Hierarchy: cluster -> category
                      values=value_column,                      # Size of each segment
                      title=chart_title,
                      height=800,
                      width=1000)
    
    fig.update_traces(textinfo='label+percent entry')  # Display both label and percentage
    fig.show()