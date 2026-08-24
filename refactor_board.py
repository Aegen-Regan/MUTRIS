import re

with open('tetris/board.lua', 'r', encoding='utf-8') as f:
    content = f.read()

# Make Board.new accept cols and rows
content = content.replace('function Board.new(x, y, player_type)', 'function Board.new(x, y, player_type, cols, rows)')
content = content.replace('self.player_type = player_type or "human"', 'self.player_type = player_type or "human"\n    self.cols = cols or 10\n    self.rows = rows or 40\n    self.visible_rows = math.floor(self.rows / 2)')

# Replace loop boundaries and 40/10 literal constants
content = re.sub(r'for r = 1, 40 do', 'for r = 1, self.rows do', content)
content = re.sub(r'for c = 1, 10 do', 'for c = 1, self.cols do', content)
content = re.sub(r'for r = 21, 40 do', 'for r = self.visible_rows + 1, self.rows do', content)
content = re.sub(r'for r = 40, 21, -1 do', 'for r = self.rows, self.visible_rows + 1, -1 do', content)
content = re.sub(r'for r = 1, 20 do', 'for r = 1, self.visible_rows do', content)

# CheckLines loop
content = re.sub(r'local r = 40', 'local r = self.rows', content)
content = re.sub(r'while r >= 21 do', 'while r >= self.visible_rows + 1 do', content)
content = re.sub(r'tx > 10', 'tx > self.cols', content)
content = re.sub(r'ty > 40', 'ty > self.rows', content)
content = re.sub(r'tx <= 10', 'tx <= self.cols', content)
content = re.sub(r'ty <= 40', 'ty <= self.rows', content)

content = content.replace('41 - r', '(self.rows + 1) - r')

# shiftColumns
content = re.sub(r'for c = 10, 2, -1 do', 'for c = self.cols, 2, -1 do', content)
content = re.sub(r'for c = 1, 9 do', 'for c = 1, self.cols - 1 do', content)
content = content.replace('self.grid[r][10]', 'self.grid[r][self.cols]')
content = content.replace('other.grid[r][10]', 'other.grid[r][self.cols]')

# Block drawing positions
content = content.replace('(r - 21) * 24', '(r - (self.visible_rows + 1)) * 24')
content = content.replace('r - 22', 'r - (self.visible_rows + 2)')

# In garbage injection
content = content.replace('self.grid[39][c]', 'self.grid[self.rows - 1][c]')
content = content.replace('self.grid[40][c]', 'self.grid[self.rows][c]')
content = content.replace('for r = 1, 39 do', 'for r = 1, self.rows - 1 do')
content = content.replace('math.random(1, 10)', 'math.random(1, self.cols)')

with open('tetris/board.lua', 'w', encoding='utf-8') as f:
    f.write(content)
