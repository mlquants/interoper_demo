import numpy as np
import pandas as pd
from datetime import datetime
pd.get_option("display.max_columns")

df = pd.read_csv("test.csv", header=None, names=["Open", "High", "Low", "Close", "Volume", "Timestamp", "BuyToSell"])
df["Timestamp"] = df["Timestamp"].apply(lambda row: pd.to_datetime(row,unit='ms'))
df['return'] = np.log(df["Close"] / df["Close"].shift(1))
df['direction'] = np.where(df['return'] > 0, 1, 0)
df.dropna(inplace=True)
df.tail()
print(df.head(10))

def preprocess():
    pass

def infer():
    pass


