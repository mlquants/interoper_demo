import pandas as pd
import numpy as np
import os
from typing import Tuple

from ta.trend import MACD
from sklearn.model_selection import train_test_split


class FeatureTransformer:
    def __init__(self,
                 signal_threshold: float = 0.15,
                 trades_per_candle: int = 1000):
        self.signal_threshold = signal_threshold
        self.trades_per_candle = trades_per_candle
        self.df = None

    @staticmethod
    def read_df_from_csv(fname: str):
        path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", fname)
        df = pd.read_csv(path, header=None, names=["Open", "High", "Low", "Close", "Volume", "Timestamp", "SelltoBuy"])
        df["Timestamp"] = df["Timestamp"].apply(lambda row: pd.to_datetime(row, unit='ms'))
        return df

    def preprocess(self):
        self.df['pct_change'] = self.df["Close"].pct_change() * 100
        self.create_signal()
        self.df['open_high_pct_change'] = (self.df['High'] - self.df['Open']) / self.df['Open'] * 100
        self.df['open_low_pct_change'] = (self.df["Low"] - self.df["Open"]) / self.df["Open"] * 100
        self.df["sell_to_buy_ratio"] = (self.df["SelltoBuy"] / self.trades_per_candle)
        self.df = self.df.drop(columns=["SelltoBuy"])
        self.df["secs_between_candles"] = self.df["Timestamp"] - self.df["Timestamp"].shift(1)
        self.df["secs_between_candles"] = self.df['secs_between_candles'].dt.total_seconds()
        self.df = self.df.drop(columns=["Timestamp"])
        self.df["ss_next"] = self.df["simple_signal"].shift(-1)
        self.df["vol_pct_change"] = self.df["Volume"].pct_change()
        self.df["vol_per_sec"] = np.log(self.df["Volume"] / self.df["secs_between_candles"])  # Can remove log if needed
        self.df = self.df.drop(columns=["Volume"])
        indicator_macd = MACD(close=self.df['Close'], window_slow=26, window_fast=12, window_sign=9, fillna=False)
        self.df['macd'] = indicator_macd.macd()
        self.df['macd_diff'] = indicator_macd.macd_diff()
        self.df['momentum'] = self.df['pct_change'].rolling(5).mean()
        # self.df['distance'] = (self.df["Close"] - self.df["Close"].rolling(50).mean())
        self.df = self.df.drop(columns=["Open", "Close", "High", "Low"])
        self.introduce_shift(1)
        # print(list(self.df))  # Debugging
        # print(self.df.tail(50)["sell_to_buy_ratio"])  # Debugging
        # print(self.df.shape)  # Debugging

    def create_signal(self,
                      signal_col_name: str = "simple_signal",
                      buy_side_col: str = "pct_change",
                      sell_side_col: str = "pct_change"):
        conditions = [(self.df[buy_side_col] > self.signal_threshold),
                      (self.df[sell_side_col] < -self.signal_threshold)]
        choices = [1, -1]
        self.df[signal_col_name] = np.select(conditions, choices, default=0)

    def introduce_shift(self, depth: int = 1):
        for i in range(depth):
            self.df[f"pct_change_{i + 1}"] = self.df["pct_change"].shift(i + 1)
            self.df[f"open_high_pct_change_{i + 1}"] = self.df["open_high_pct_change"].shift(i + 1)
            self.df[f"open_low_pct_change_{i + 1}"] = self.df["open_low_pct_change"].shift(i + 1)
            self.df[f"sell_to_buy_ratio_{i + 1}"] = self.df["sell_to_buy_ratio"].shift(i + 1)
            self.df[f"secs_between_candles_{i + 1}"] = self.df["secs_between_candles"].shift(i + 1)


class FeatureTransformerInference(FeatureTransformer):
    def __init__(self, fname: str = "test_ethusdt_size.csv", num_rows_to_keep_in_cache: int = 40, **kwargs):
        super().__init__(**kwargs)
        self.num_rows_to_keep_in_cache = num_rows_to_keep_in_cache
        self.cache = self.create_cache(fname, num_rows_to_keep_in_cache)

    def create_cache(self, fname: str, num_rows: int) -> pd.DataFrame:
        df = self.read_df_from_csv(fname)
        return df.tail(num_rows)

    def transform_observation_to_feature_vector(self, row: dict) -> pd.DataFrame:
        pretty_row = {"Open": [row["open"]], "Close": [row["close"]], "High": [row["high"]], "Low": [row["low"]],
                      "Volume": [row["volume"]], "Timestamp": [row["timestamp"]], "SelltoBuy": [row["b2s"]]}
        entry = pd.DataFrame.from_dict(pretty_row)
        entry["Timestamp"] = entry["Timestamp"].apply(lambda a_row: pd.to_datetime(a_row, unit='ms'))
        self.df = self.cache.append(entry)
        self.cache = self.df.tail(self.num_rows_to_keep_in_cache).__deepcopy__()
        self.preprocess()
        X = self.df.drop(columns=["ss_next"])
        return X.tail(1)


class FeatureTransformerTraining(FeatureTransformer):
    def __init__(self, fname: str = "test_ethusdt_size.csv", test_size: float = 0.15, random_state: int = 42, **kwargs):
        self.test_size = test_size
        self.random_state = random_state
        df = self.read_df_from_csv(fname)
        super().__init__(**kwargs)
        self.df = df

    def split_train_test(self) -> Tuple[pd.DataFrame, pd.Series, pd.DataFrame, pd.Series]:
        self.preprocess()
        self.df.dropna(inplace=True)
        y = self.df["ss_next"]
        X = self.df.drop(columns=["ss_next"])
        X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=self.test_size,
                                                            random_state=self.random_state,
                                                            shuffle=False)
        return X_train, y_train, X_test, y_test


if __name__ == "__main__":
    f = FeatureTransformerTraining()
    f.preprocess()
