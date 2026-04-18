### Syntax and functional correctness
_samples per task = 5, temperature = 0.2_
<table>
  <thead>
    <tr>
      <th rowspan="2">task (top module)</th>
      <th colspan="3">llm_1</th>
      <th colspan="3">llm_2</th>
    </tr>
    <tr>
      <th>syntax</th>
      <th>functional</th>
      <th>lint</th>
      <th>syntax</th>
      <th>functional</th>
      <th>lint</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>task_01 (secure_reg)</td>
      <td>5</td>
      <td>3</td>
      <td>5</td>
      <td>3</td>
      <td>5</td>
      <td>3</td>
    </tr>
    <tr>
      <td>task_06 (shared_reg)</td>
      <td>5</td>
      <td>4</td>
      <td>5</td>
      <td>3</td>
      <td>4</td>
      <td>5</td>
    </tr>
    <tr>
      <td>pass@1</td>
      <td colspan="3">0.5678</td>
      <td colspan="3">0.1234</td>
    </tr>
  </tbody>
</table>

### Area and timing
_samples per task = 5, temperature = 0.2_
<table>
  <thead>
    <tr>
      <th rowspan="2">task (top module)</th>
      <th colspan="3">llm_1</th>
      <th colspan="3">llm_2</th>
    </tr>
    <tr>
      <th>synthesizable</th>
      <th>area</th>
      <th>timing</th>
      <th>synthesizable</th>
      <th>area</th>
      <th>timing</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>task_01 (secure_reg)</td>
      <td>5</td>
      <td>3</td>
      <td>5</td>
      <td>3</td>
      <td>5</td>
      <td>3</td>
    </tr>
    <tr>
      <td>task_06 (shared_reg)</td>
      <td>5</td>
      <td>4</td>
      <td>5</td>
      <td>3</td>
      <td>5</td>
      <td>3</td>
    </tr>
  </tbody>
</table>