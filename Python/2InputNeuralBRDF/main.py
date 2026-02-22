import math
import os
import time

import coremltools as ct
import torch
import torch.nn as nn
import torchvision.transforms.functional as TF
from PIL import Image
from torch.utils.data import DataLoader, TensorDataset

L = 12
ENCODED_DIM = 2 + 4 * L


def positional_encode(x: torch.Tensor) -> torch.Tensor:
    freqs = [2**i for i in range(L)]
    encoded = [x]
    for f in freqs:
        encoded += [torch.sin(f * math.pi * x), torch.cos(f * math.pi * x)]
    return torch.cat(encoded, dim=-1)


class TwoInputNeuralBRDFModel(nn.Module):
    def __init__(self, hidden=128, depth=3):
        super().__init__()
        layers = [nn.Linear(ENCODED_DIM, hidden), nn.GELU()]
        for _ in range(depth - 1):
            layers += [nn.Linear(hidden, hidden), nn.GELU()]
        layers += [nn.Linear(hidden, 3), nn.Sigmoid()]
        self.net = nn.Sequential(*layers)

    def forward(self, x):
        return self.net(positional_encode(x))

    def save(self, path):
        torch.save(self.net.state_dict(), path)

    def load(self, path):
        self.net.load_state_dict(torch.load(path, weights_only=True))
        self.eval()


class TwoInputNeuralBRDFModelTraining:
    def __init__(self, path):
        img = Image.open(path).convert("RGB")
        img_tensor = TF.to_tensor(img)
        dimension = img_tensor.shape[-1]

        u = torch.linspace(-1.0, 1.0, dimension)
        v = torch.linspace(-1.0, 1.0, dimension)
        grid_v, grid_u = torch.meshgrid(v, u, indexing="ij")
        self.X = torch.stack([grid_u.flatten(), grid_v.flatten()], dim=1)

        r = img_tensor[0].flatten()
        g = img_tensor[1].flatten()
        b = img_tensor[2].flatten()
        self.Y = torch.stack([r, g, b], dim=1)

        self.mse = nn.MSELoss()
        self.l1 = nn.L1Loss()

    def infer(self, model: TwoInputNeuralBRDFModel, path: str):
        with torch.no_grad():
            y_pred = model(self.X)
        dimension = int(self.X.shape[0] ** 0.5)
        r = y_pred[:, 0].reshape(dimension, dimension)
        g = y_pred[:, 1].reshape(dimension, dimension)
        b = y_pred[:, 2].reshape(dimension, dimension)
        img_tensor = torch.stack([r, g, b], dim=0)
        img = TF.to_pil_image(img_tensor.clamp(0, 1))
        img.save(path)

    def loss(self, pred, target):
        return self.mse(pred, target) + 0.1 * self.l1(pred, target)

    def train(
        self,
        model: TwoInputNeuralBRDFModel,
        lr: float,
        epochs: int,
        batch_size: int = 4096,
    ):
        dataset = TensorDataset(self.X, self.Y)
        loader = DataLoader(dataset, batch_size=batch_size, shuffle=True)
        optimizer = torch.optim.Adam(model.parameters(), lr=lr)
        loss_fn = self.loss
        scheduler = torch.optim.lr_scheduler.CosineAnnealingLR(optimizer, T_max=epochs)
        for epoch in range(epochs):
            total_loss = 0.0
            for X_batch, Y_batch in loader:
                y_pred = model(X_batch)
                loss = loss_fn(y_pred, Y_batch)
                optimizer.zero_grad()
                loss.backward()
                optimizer.step()
                total_loss += loss.item()
            scheduler.step()
            print(f"Epoch {epoch}, Loss: {total_loss / len(loader):.6f}")


def main():
    model = TwoInputNeuralBRDFModel()
    os.makedirs("Assets/Models/PTH", exist_ok=True)

    if os.path.exists("Assets/Models/Base/2_input_neural_brdf.pth"):
        model.load("Assets/Models/Base/2_input_neural_brdf.pth")
    else:
        print("Training...")
        trainer = TwoInputNeuralBRDFModelTraining("Assets/TestTexture.png")

        start = time.time()
        trainer.train(model=model, lr=0.01, epochs=100, batch_size=4096)
        print(f"Training time: {time.time() - start:.2f} seconds")
        trainer.infer(model, "Assets/InferredTestTexture.png")

        model.save("Assets/Models/Base/2_input_neural_brdf.pth")
    model.eval()

    dummy_input = torch.zeros(1, 2)
    traced = torch.jit.trace(model, dummy_input)
    coremlmodel = ct.convert(
        traced,
        inputs=[ct.TensorType(name="uv", shape=(1, 2))],
        outputs=[ct.TensorType(name="rgb")],
        convert_to="mlprogram",
        minimum_deployment_target=ct.target.macOS15,
    )
    coremlmodel.save("Assets/Models/Base/2_input_neural_brdf.mlpackage")


if __name__ == "__main__":
    main()
