import gleam/int
import gleam/float
import gleam/erlang/process.{ProcessDown}

pub fn self_test() {
  let subject = process.new_subject()
  let pid = process.self()

  assert True = pid == process.self()
  assert False = pid == process.start(fn() { Nil }, linked: True)

  process.start(fn() { process.send(subject, process.self()) }, linked: True)
  assert Ok(child_pid) = process.receive(subject, 5)
  assert True = child_pid != process.self()
}

pub fn sleep_test() {
  // Exists just to ensure the function does not error
  process.sleep(1)
}

pub fn subject_owner_test() {
  let subject = process.new_subject()
  assert True = process.subject_owner(subject) == process.self()
}

pub fn receive_test() {
  let subject = process.new_subject()

  // Send message from self
  process.send(subject, 0)

  // Send message from another process
  process.start(
    fn() {
      process.send(subject, 1)
      process.send(subject, 2)
    },
    linked: True,
  )

  // Assert all the messages arrived
  assert Ok(0) = process.receive(subject, 0)
  assert Ok(1) = process.receive(subject, 50)
  assert Ok(2) = process.receive(subject, 0)
  assert Error(Nil) = process.receive(subject, 0)
}

pub fn is_alive_test() {
  let pid = process.start(fn() { Nil }, False)
  process.sleep(5)
  assert False = process.is_alive(pid)
}

pub fn sleep_forever_test() {
  let pid = process.start(process.sleep_forever, False)
  process.sleep(5)
  assert True = process.is_alive(pid)
}

pub fn selector_test() {
  let subject1 = process.new_subject()
  let subject2 = process.new_subject()
  let subject3 = process.new_subject()

  process.send(subject1, "1")
  process.send(subject2, 2)
  process.send(subject3, 3.0)

  let selector =
    process.new_selector()
    |> process.selecting(subject2, int.to_string)
    |> process.selecting(subject3, float.to_string)

  // We can selectively receive messages for subjects 2 and 3, skipping the one
  // from subject 1 even though it is first in the mailbox.
  assert Ok("2") = process.select(selector, 0)
  assert Ok("3.0") = process.select(selector, 0)
  assert Error(Nil) = process.select(selector, 0)

  // More messages for subjects 2 and 3
  process.send(subject2, 2)
  process.send(subject3, 3.0)

  // Include subject 1 also
  let selector = process.selecting(selector, subject1, fn(x) { x })

  // Now we get the message for subject 1 first as it is first in the mailbox
  assert Ok("1") = process.select(selector, 0)
  assert Ok("2") = process.select(selector, 0)
  assert Ok("3.0") = process.select(selector, 0)
  assert Error(Nil) = process.select(selector, 0)
}

pub fn monitor_test_test() {
  // Spawn child
  let parent_subject = process.new_subject()
  let pid =
    process.start(
      linked: False,
      running: fn() {
        let subject = process.new_subject()
        process.send(parent_subject, subject)
        // Wait for the parent to send a message before exiting
        process.receive(subject, 150)
      },
    )

  // Monitor child
  let monitor = process.monitor_process(pid)

  // There is no monitor message while the child is alive
  assert Error(Nil) =
    process.new_selector()
    |> process.selecting_process_down(monitor, fn(x) { x })
    |> process.select(0)

  // Shutdown child to trigger monitor
  assert Ok(child_subject) = process.receive(parent_subject, 50)
  process.send(child_subject, Nil)

  // We get a process down message!
  assert Ok(ProcessDown(downed_pid, _reason)) =
    process.new_selector()
    |> process.selecting_process_down(monitor, fn(x) { x })
    |> process.select(50)

  assert True = downed_pid == pid
}
// fn call_message(value) {
//   fn(reply_channel) { #(value, reply_channel) }
// }

// pub fn try_call_test() {
//   let parent_subject = process.new_subject()

//   process.start(
//     linked: True,
//     running: fn() {
//       // Send the child subject to the parent so it can call the child
//       let child_subject = process.new_subject()
//       process.send(parent_subject, child_subject)
//       // Wait for the channel to be called
//       assert Ok(#(x, reply)) = process.receive(child_subject, 50)
//       // Reply
//       process.send(reply, x + 1)
//     },
//   )

//   assert Ok(call_sender) = process.receive(parent_subject, 50)

//   // Call the child process over the channel
//   call_sender
//   |> process.try_call(call_message(1), 50)
//   |> should.equal(Ok(2))
// }

// pub fn try_call_timeout_test() {
//   let #(parent_sender, parent_receiver) = process.new_channel()

//   process.start(fn() {
//     // Send the call channel to the parent
//     let #(call_sender, call_receiver) = process.new_channel()
//     process.send(parent_sender, call_sender)
//     // Wait for the channel to be called
//     assert Ok(#(x, reply_channel)) = process.receive(call_receiver, 50)
//     // Reply, after a delay
//     sleep(20)
//     process.send(reply_channel, x + 1)
//   })

//   assert Ok(call_sender) = process.receive(parent_receiver, 50)

//   // Call the child process over the channel
//   call_sender
//   |> process.try_call(call_message(1), 10)
//   |> result.is_error
//   |> should.be_true
// }