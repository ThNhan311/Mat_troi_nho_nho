import assert from 'node:assert/strict';
export function verifyAccountResource(resource, instance) {
  assert.match(resource.containerId,/^[a-f0-9]{64}$/);
  assert.match(resource.image,/^sha256:[a-f0-9]{64}$/);
  assert.equal(instance.Id,resource.containerId); assert.equal(instance.Image,resource.image);
  assert.equal(resource.port,15441);
  assert.equal(instance.Config.Labels['fitcenter.task'],'account-20261123');
  const mounts=instance.Mounts.filter(x=>x.Destination==='/var/lib/postgresql/data');
  assert.equal(mounts.length,1); assert.equal(mounts[0].Type,'volume'); assert.equal(mounts[0].Name,resource.volume);
  assert.deepEqual(instance.HostConfig.PortBindings['5432/tcp'],[{HostIp:'127.0.0.1',HostPort:'15441'}]);
  const legacy=resource.container==='fitcenter-account-20261123-db' && resource.volume==='fitcenter_account_20261123_data';
  if (!legacy) {
    assert.match(resource.scope,/^[a-f0-9]{12}$/);
    assert.equal(resource.container,`fitcenter-core-${resource.scope}-db`);
    assert.equal(resource.volume,`fitcenter_core_${resource.scope}_data`);
    assert.equal(instance.Config.Labels['fitcenter.scope'],resource.scope);
  }
  assert.equal(instance.State.Running,true);
}
