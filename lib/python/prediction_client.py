import os
import pickle

from sklearn.ensemble import RandomForestClassifier

from feature_transformation import FeatureTransformerTraining


class RandomForestClient:
    def __init__(self, num_estimators: int = 3000, max_depth: int = 4, mode: str = "inference"):
        if mode == "inference":
            self.load()
        else:
            self.model = RandomForestClassifier(n_estimators=num_estimators, max_depth=max_depth)

    def train(self, x_tr, y_tr):
        self.model.fit(x_tr, y_tr)

    def save(self, fname: str = "rf_model.pickle"):
        path = os.path.join(os.path.dirname(os.path.abspath(__file__)), fname)
        with open(path, 'wb') as fh:
            pickle.dump(self.model, fh)

    def load(self, fname: str = "rf_model.pickle"):
        path = os.path.join(os.path.dirname(os.path.abspath(__file__)), fname)
        with open(path, 'rb') as fh:
            self.model = pickle.load(fh)

    def predict(self, x_test):
        return self.model.predict(x_test)


if __name__ == "__main__":
    f = FeatureTransformerTraining()
    x_train, y_train, _, _ = f.split_train_test()
    r = RandomForestClient(mode="train")
    r.train(x_train, y_train)
    r.save()


