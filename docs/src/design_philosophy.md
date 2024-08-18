# Design Philosophy

The design of this project is grounded in several key principles aimed at ensuring flexibility, modularity, and ease of use. These principles guide the structure and development of the codebase, making it robust and adaptable to future development.

## 1. Modularity

The codebase is designed with modularity in mind. By defining abstract types and leveraging Julia's multiple dispatch feature, we allow for the seamless addition of new model types and functionalities. Each component, whether it be AC, DC, or uncertainty models, can be developed and maintained independently. This modular approach ensures that changes in one part of the system do not inadvertently impact others.

## 2. Separation of Concerns

The design follows the principle of separation of concerns, where each part of the system has a distinct responsibility. For instance, the factories are responsible for creating models, while the models themselves encapsulate the specific optimization logic. This separation helps in isolating and addressing issues, testing components independently, and ensuring that each part of the system can evolve without causing disruptions.

## 3. Reusability

Reusability is emphasized through the use of common abstract interfaces and the implementation of general functions that can operate on any subtype. For example, the `optimize_model` function can be used with any model that conforms to the `AbstractMPOPFModel` interface.