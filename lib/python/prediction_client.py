import os
import pickle
import abc
import random

from sklearn.ensemble import RandomForestClassifier

from feature_transformation import FeatureTransformerTraining


class Client(metaclass=abc.ABCMeta):
    @abc.abstractmethod
    def predict_one(self, x_test):
        pass


class RandomClient(Client):
    def predict_one(self, x_test):
        return random.choice([-1, 0, 1])


class RandomForestClient(Client):
    def __init__(self, num_estimators: int = 3000, max_depth: int = 4, mode: str = "inference", fname: str = "rf_model.pickle"):
        self.fname = fname
        if mode == "inference":
            self.load()
        else:
            self.model = RandomForestClassifier(n_estimators=num_estimators, max_depth=max_depth)

    def train(self, x_tr, y_tr):
        self.model.fit(x_tr, y_tr)

    def save(self):
        path = os.path.join(os.path.dirname(os.path.abspath(__file__)), self.fname)
        with open(path, 'wb') as fh:
            pickle.dump(self.model, fh)

    def load(self):
        path = os.path.join(os.path.dirname(os.path.abspath(__file__)), self.fname)
        with open(path, 'rb') as fh:
            self.model = pickle.load(fh)

    def predict_one(self, x_test):
        return int(self.model.predict(x_test)[0])


if __name__ == "__main__":
    f = FeatureTransformerTraining()
    x_train, y_train, _, _ = f.split_train_test()
    r = RandomForestClient(mode="train")
    r.train(x_train, y_train)
    r.save()
