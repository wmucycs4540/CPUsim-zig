from collections import deque


class Queue(deque):
    def peek(self):
        return self[0] if len(self) > 0 else None

    def enque(self, e):
        self.append(e)

    def deque(self):
        return self.popleft() if len(self) > 0 else None

    def deque_at(self, index):
        r = len(self) - index - 1
        self.rotate(-index)
        e = self.deque()
        self.rotate(-r)
        return e
